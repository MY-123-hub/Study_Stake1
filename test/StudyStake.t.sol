// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StudyStake.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice 模拟 USDC 代币用于测试
contract MockUSDC {
    uint8 private _decimals;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address spender, uint256 value);

    constructor() { _decimals = 6; }

    function decimals() external view returns (uint8) { return _decimals; }
    function name() external pure returns (string memory) { return "USD Coin"; }
    function symbol() external pure returns (string memory) { return "USDC"; }
    function totalSupply() external view returns (uint256) { return 1_000_000 * 1e6; }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(_balances[from] >= amount, "Insufficient balance");
        require(_allowances[from][msg.sender] >= amount, "Insufficient allowance");
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract StudyStakeTest is Test {
    StudyStake public implementation;
    StudyStake public stake;
    ERC1967Proxy public proxy;
    MockUSDC public usdc;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public penaltyReceiver = makeAddr("penalty_receiver");

    uint256 constant USDC_DECIMALS = 1e6;
    uint256 constant DEPOSIT_AMOUNT = 100 * USDC_DECIMALS;
    uint256 constant PENALTY_AMOUNT = 20 * USDC_DECIMALS;

    bytes4 constant LIBRARY_TAG_A = 0xA1B2C3D4;
    bytes4 constant WRONG_TAG     = 0xDEADBEEF;

    // ============================================================
    //  辅助函数 — 避免解构地狱！
    // ============================================================

    /// @notice 获取任务的指定字段值（无需完整解构）
    function _taskStatus(address u, uint256 tid) internal view returns (StudyStake.TaskStatus) {
        // 8 fields: id,user,targetTime,window,penalty,mode,allowedTag,status
        // Get field 8 (status): skip first 7 with 7 commas total
        (,,,,,, ,StudyStake.TaskStatus s) = stake.tasks(u, tid);
        return s;
    }

    function _taskMode(address u, uint256 tid) internal view returns (StudyStake.CheckInMode) {
        // Fields: [id(0),user(1),targetTime(2),window(3),penalty(4),mode(5),allowedTag(6),status(7)]
        // Want field 5 (mode): skip 5, capture, skip 2 more = 8 items, 7 commas
        (,,,,, StudyStake.CheckInMode m, ,) = stake.tasks(u, tid);
        return m;
    }

    function _taskTag(address u, uint256 tid) internal view returns (bytes4) {
        (,,,,,, bytes4 t,) = stake.tasks(u, tid);
        return t;
    }

    function deployAndInitialize() internal {
        vm.startPrank(owner);
        usdc = new MockUSDC();
        implementation = new StudyStake();

        bytes memory initData = abi.encodeWithSelector(
            StudyStake.initialize.selector,
            address(usdc),
            penaltyReceiver
        );

        proxy = new ERC1967Proxy(address(implementation), initData);
        stake = StudyStake(address(proxy));
        vm.stopPrank();
    }

    function setUp() public {
        deployAndInitialize();
        usdc.mint(user, 1000 * USDC_DECIMALS);
        vm.prank(user);
        usdc.approve(address(stake), type(uint256).max);
    }

    // ============================================================
    //  初始化 & 升级
    // ============================================================

    function test_initialization() public view {
        assertEq(address(stake.usdc()), address(usdc));
        assertEq(stake.penaltyReceiver(), penaltyReceiver);
        assertEq(stake.VERSION(), 1);
        assertEq(stake.owner(), owner);
    }

    function test_cannot_reinitialize() public {
        vm.prank(owner);
        vm.expectRevert();
        stake.initialize(address(usdc), penaltyReceiver);
    }

    function test_upgrade_only_owner_can_upgrade() public {
        StudyStake v2Impl = new StudyStake();
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert();
        stake.upgradeToAndCall(address(v2Impl), "");
    }

    function test_successful_upgrade() public {
        StudyStake v2Impl = new StudyStake();
        vm.prank(owner);
        stake.upgradeToAndCall(address(v2Impl), "");
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);
        assertEq(stake.balances(user), DEPOSIT_AMOUNT);
    }

    // ============================================================
    //  Pausable
    // ============================================================

    function test_pause_and_unpause() public {
        vm.prank(owner);
        stake.pause();
        assertTrue(stake.paused());

        vm.prank(user);
        vm.expectRevert();
        stake.deposit(DEPOSIT_AMOUNT);

        vm.prank(owner);
        stake.unpause();
        assertFalse(stake.paused());

        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);
        assertEq(stake.balances(user), DEPOSIT_AMOUNT);
    }

    // ============================================================
    //  流程1：资金准备
    // ============================================================

    function test_deposit() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);
        assertEq(stake.balances(user), DEPOSIT_AMOUNT);
    }

    function test_withdraw_success() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);
        vm.prank(user);
        stake.withdraw(50 * USDC_DECIMALS);
        assertEq(stake.balances(user), 50 * USDC_DECIMALS);
        assertEq(usdc.balanceOf(user), 950 * USDC_DECIMALS);
    }

    function test_cannot_withdraw_more_than_balance() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);
        vm.expectRevert("Insufficient balance");
        vm.prank(user);
        stake.withdraw(200 * USDC_DECIMALS);
    }

    function test_cannot_withdraw_locked_by_active_task() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);
        uint256 tomorrow = block.timestamp + 1 days;
        vm.prank(user);
        stake.createTask(tomorrow, 1800, PENALTY_AMOUNT, StudyStake.CheckInMode.Click, bytes4(0));

        vm.expectRevert("Balance locked by active tasks");
        vm.prank(user);
        stake.withdraw(90 * USDC_DECIMALS);

        vm.prank(user);
        stake.withdraw(80 * USDC_DECIMALS);
        assertEq(stake.balances(user), 20 * USDC_DECIMALS);
    }

    function test_available_balance() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);
        assertEq(stake.availableBalance(user), DEPOSIT_AMOUNT);

        uint256 tomorrow = block.timestamp + 1 days;
        vm.prank(user);
        stake.createTask(tomorrow, 1800, PENALTY_AMOUNT, StudyStake.CheckInMode.NFC, LIBRARY_TAG_A);
        assertEq(stake.availableBalance(user), DEPOSIT_AMOUNT - PENALTY_AMOUNT);
    }

    // ============================================================
    //  Owner 权限
    // ============================================================

    function test_set_penalty_receiver() public {
        address newReceiver = makeAddr("new_receiver");
        vm.prank(owner);
        stake.setPenaltyReceiver(newReceiver);
        assertEq(stake.penaltyReceiver(), newReceiver);
    }

    function test_non_owner_cannot_set_penalty_receiver() public {
        address newReceiver = makeAddr("new_receiver");
        vm.expectRevert();
        vm.prank(user);
        stake.setPenaltyReceiver(newReceiver);
    }

    // ============================================================
    //  流程2：创建任务 — Click 模式
    // ============================================================

    function test_create_click_task() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.startPrank(user);

        uint256 taskId = stake.createTask(
            targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.Click, bytes4(0)
        );
        assertEq(taskId, 1);
        assertEq(stake.taskCount(user), 1);

        // 完整解构验证所有 8 个字段
        (
            uint256 id,
            address u,
            uint256 tt,
            uint256 w,
            uint256 p,
            StudyStake.CheckInMode mode,
            bytes4 tag,
            StudyStake.TaskStatus status
        ) = stake.tasks(user, 1);

        assertEq(id, 1);
        assertEq(u, user);
        assertEq(tt, targetTime);
        assertEq(w, 1800);
        assertEq(p, PENALTY_AMOUNT);
        assertEq(uint256(mode), uint256(StudyStake.CheckInMode.Click));
        assertEq(tag, bytes4(0));
        assertEq(uint256(status), uint256(StudyStake.TaskStatus.Active));

        vm.stopPrank();
    }

    function test_create_simple_task_convenience() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createSimpleTask(targetTime, 1800, PENALTY_AMOUNT);

        assertEq(uint256(_taskMode(user, taskId)), uint256(StudyStake.CheckInMode.Click));
    }

    // ============================================================
    //  流程2：创建任务 — NFC 模式
    // ============================================================

    function test_create_nfc_task() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(
            targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.NFC, LIBRARY_TAG_A
        );

        assertEq(_taskTag(user, taskId), LIBRARY_TAG_A);
        assertEq(uint256(_taskMode(user, taskId)), uint256(StudyStake.CheckInMode.NFC));
    }

    function test_nfc_requires_valid_tag() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);
        uint256 targetTime = block.timestamp + 1 days;

        vm.expectRevert("NFC requires a valid tag");
        vm.prank(user);
        stake.createTask(
            targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.NFC, bytes4(0)
        );
    }

    function test_click_mode_forces_tag_to_zero() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);
        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        stake.createTask(
            targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.Click, WRONG_TAG
        );

        assertEq(_taskTag(user, 1), bytes4(0));
    }

    function test_create_mixed_mode_tasks() public {
        vm.prank(user);
        stake.deposit(200 * USDC_DECIMALS);

        vm.startPrank(user);
        stake.createTask(block.timestamp + 1 days, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.NFC, LIBRARY_TAG_A);
        stake.createTask(block.timestamp + 2 days, 3600, 30 * USDC_DECIMALS,
            StudyStake.CheckInMode.Click, bytes4(0));
        vm.stopPrank();

        assertEq(stake.taskCount(user), 2);
    }

    function test_create_task_must_be_future() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);
        vm.warp(365 days);

        vm.startPrank(user);
        vm.expectRevert("Target must be in future");
        stake.createTask(block.timestamp - 100, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.Click, bytes4(0));
        vm.stopPrank();
    }

    // ============================================================
    //  流程3a：点击签到
    // ============================================================

    function test_click_checkin_success() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.Click, bytes4(0));

        vm.warp(targetTime + 900);
        vm.prank(user);
        stake.checkIn(taskId);

        assertEq(uint256(_taskStatus(user, taskId)), uint256(StudyStake.TaskStatus.Completed));
    }

    function test_click_checkin_at_target_time() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.Click, bytes4(0));

        vm.warp(targetTime);
        vm.prank(user);
        stake.checkIn(taskId);

        assertEq(uint256(_taskStatus(user, taskId)), uint256(StudyStake.TaskStatus.Completed));
    }

    function test_click_checkin_fails_too_early() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.Click, bytes4(0));

        vm.warp(targetTime - 1);
        vm.expectRevert("Too early to check in");
        vm.prank(user);
        stake.checkIn(taskId);
    }

    function test_click_checkin_fails_after_window() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.Click, bytes4(0));

        vm.warp(targetTime + 1801);
        vm.expectRevert("Window expired - too late");
        vm.prank(user);
        stake.checkIn(taskId);
    }

    // ============================================================
    //  核心安全：NFC 任务不能用点击签到！
    // ============================================================

    function test_nfc_task_rejects_click_checkin() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.NFC, LIBRARY_TAG_A);

        vm.warp(targetTime + 900);
        vm.expectRevert("This task requires NFC check-in");
        vm.prank(user);
        stake.checkIn(taskId);

        // 状态仍然是 Active
        assertEq(uint256(_taskStatus(user, taskId)), uint256(StudyStake.TaskStatus.Active));
    }

    // ============================================================
    //  流程3b：NFC 签到
    // ============================================================

    function test_nfc_checkin_success() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.NFC, LIBRARY_TAG_A);

        vm.warp(targetTime + 900);
        vm.prank(user);
        stake.checkInWithNFC(taskId, LIBRARY_TAG_A);

        assertEq(uint256(_taskStatus(user, taskId)), uint256(StudyStake.TaskStatus.Completed));
    }

    function test_nfc_checkin_wrong_tag_rejected() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.NFC, LIBRARY_TAG_A);

        vm.warp(targetTime + 900);
        vm.expectRevert("Wrong NFC tag");
        vm.prank(user);
        stake.checkInWithNFC(taskId, WRONG_TAG);

        assertEq(uint256(_taskStatus(user, taskId)), uint256(StudyStake.TaskStatus.Active));
    }

    function test_nfc_checkin_only_works_on_nfc_tasks() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.Click, bytes4(0));

        vm.warp(targetTime + 900);
        vm.expectRevert("This task is click-only mode");
        vm.prank(user);
        stake.checkInWithNFC(taskId, LIBRARY_TAG_A);
    }

    function test_nfc_checkin_time_window_enforcement() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.NFC, LIBRARY_TAG_A);

        vm.warp(targetTime - 1);
        vm.expectRevert("Too early to check in");
        vm.prank(user);
        stake.checkInWithNFC(taskId, LIBRARY_TAG_A);

        vm.warp(targetTime + 1801);
        vm.expectRevert("Window expired - too late");
        vm.prank(user);
        stake.checkInWithNFC(taskId, LIBRARY_TAG_A);
    }

    function test_only_user_can_nfc_checkin() public {
        address attacker = makeAddr("attacker");

        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.NFC, LIBRARY_TAG_A);

        vm.warp(targetTime + 900);
        vm.expectRevert("Not your task");
        vm.prank(attacker);
        stake.checkInWithNFC(taskId, LIBRARY_TAG_A);
    }

    // ============================================================
    //  流程4：违约清算
    // ============================================================

    function test_slash_click_task() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.Click, bytes4(0));

        vm.warp(targetTime + 3600);
        stake.slash(user, taskId);

        assertEq(uint256(_taskStatus(user, taskId)), uint256(StudyStake.TaskStatus.Slashed));
        assertEq(usdc.balanceOf(penaltyReceiver), PENALTY_AMOUNT);
        assertEq(stake.balances(user), DEPOSIT_AMOUNT - PENALTY_AMOUNT);
    }

    function test_slash_nfc_task() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.NFC, LIBRARY_TAG_A);

        vm.warp(targetTime + 3600);
        stake.slash(user, taskId);

        assertEq(uint256(_taskStatus(user, taskId)), uint256(StudyStake.TaskStatus.Slashed));
        assertEq(usdc.balanceOf(penaltyReceiver), PENALTY_AMOUNT);
    }

    function test_slash_cannot_be_called_twice() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.Click, bytes4(0));

        vm.warp(targetTime + 3601);
        stake.slash(user, taskId);

        vm.expectRevert("Task not active");
        stake.slash(user, taskId);
    }

    function test_slash_cannot_during_window() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.NFC, LIBRARY_TAG_A);

        vm.warp(targetTime + 900);
        vm.expectRevert("Still within window");
        stake.slash(user, taskId);
    }

    // ============================================================
    //  完整流程 — Click happy path
    // ============================================================

    function test_full_lifecycle_click_happy_path() public {
        // 1. 存入
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);
        assertEq(stake.balances(user), DEPOSIT_AMOUNT);

        // 2. 创建点击任务
        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.Click, bytes4(0));
        assertEq(stake.taskCount(user), 1);

        // 3. 锁定余额减少
        assertEq(stake.availableBalance(user), 80 * USDC_DECIMALS);

        // 4. 点击签到
        vm.warp(targetTime + 600);
        vm.prank(user);
        stake.checkIn(taskId);

        // 5. 完成，解锁恢复
        assertEq(uint256(_taskStatus(user, taskId)), uint256(StudyStake.TaskStatus.Completed));
        assertEq(stake.availableBalance(user), DEPOSIT_AMOUNT);

        // 6. 提现全部
        vm.prank(user);
        stake.withdraw(DEPOSIT_AMOUNT);
        assertEq(stake.balances(user), 0);
        assertEq(usdc.balanceOf(user), 1000 * USDC_DECIMALS);
    }

    // ============================================================
    //  完整流程 — NFC happy path
    // ============================================================

    function test_full_lifecycle_nfc_happy_path() public {
        // 1. 存入
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        // 2. 创建 NFC 任务
        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.NFC, LIBRARY_TAG_A);

        // 3. 走到图书馆，触碰 NFC 标签
        vm.warp(targetTime + 600);
        vm.prank(user);
        stake.checkInWithNFC(taskId, LIBRARY_TAG_A);

        // 4. 完成
        assertEq(uint256(_taskStatus(user, taskId)), uint256(StudyStake.TaskStatus.Completed));
        assertEq(stake.availableBalance(user), DEPOSIT_AMOUNT);

        // 5. 提现
        vm.prank(user);
        stake.withdraw(DEPOSIT_AMOUNT);
        assertEq(usdc.balanceOf(user), 1000 * USDC_DECIMALS);
    }

    // ============================================================
    //  完整流程 — NFC fail path
    // ============================================================

    function test_full_lifecycle_nfc_fail_path() public {
        // 1. 存入
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        // 2. 创建 NFC 任务
        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 taskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.NFC, LIBRARY_TAG_A);

        // 3. 没去图书馆，超时了
        vm.warp(targetTime + 7200);

        // 4. 触发清算
        stake.slash(user, taskId);

        // 5. 被扣了 20 USDC
        assertEq(uint256(_taskStatus(user, taskId)), uint256(StudyStake.TaskStatus.Slashed));
        assertEq(usdc.balanceOf(penaltyReceiver), PENALTY_AMOUNT);
        assertEq(stake.balances(user), 80 * USDC_DECIMALS);

        // 6. 提取剩余 80
        vm.prank(user);
        stake.withdraw(80 * USDC_DECIMALS);
        assertEq(stake.balances(user), 0);
    }

    // ============================================================
    //  数据持久化（升级后数据不丢失）
    // ============================================================

    function test_data_persists_after_upgrade() public {
        vm.prank(user);
        stake.deposit(DEPOSIT_AMOUNT);

        // 创建 NFC 任务并完成签到
        uint256 targetTime = block.timestamp + 1 days;
        vm.prank(user);
        uint256 nfcTaskId = stake.createTask(targetTime, 1800, PENALTY_AMOUNT,
            StudyStake.CheckInMode.NFC, LIBRARY_TAG_A);

        vm.warp(targetTime + 600);
        vm.prank(user);
        stake.checkInWithNFC(nfcTaskId, LIBRARY_TAG_A);

        // 记录状态
        uint256 preBal = stake.balances(user);
        uint256 preCnt = stake.taskCount(user);
        StudyStake.TaskStatus preStatus = _taskStatus(user, nfcTaskId);
        bytes4 preTag = _taskTag(user, nfcTaskId);
        StudyStake.CheckInMode preMode = _taskMode(user, nfcTaskId);

        // 升级
        StudyStake v2Impl = new StudyStake();
        vm.prank(owner);
        stake.upgradeToAndCall(address(v2Impl), "");

        // 验证数据完整
        assertEq(stake.balances(user), preBal);
        assertEq(stake.taskCount(user), preCnt);
        assertEq(uint256(_taskStatus(user, nfcTaskId)), uint256(preStatus));
        assertEq(_taskTag(user, nfcTaskId), preTag);
        assertEq(uint256(_taskMode(user, nfcTaskId)), uint256(preMode));
        assertEq(address(stake.usdc()), address(usdc));
        assertEq(stake.penaltyReceiver(), penaltyReceiver);
    }
}
