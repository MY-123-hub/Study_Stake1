// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/// @title StudyStake - 自律质押协议 V1.0 (UUPS 可升级)
/// @notice 通过质押 USDC 设定目标，按时签到保留资金，逾期扣罚
/// @dev UUPS Proxy 模式：Implementation 可随时升级，Proxy 地址不变
///
/// ## 存储布局（V1）— 升级时必须遵守
/// 父合约变量 (slot 0-N):
///   OwnableUpgradeable: _owner
///   ERC1967 (UUPS): 内部管理 slot
///   PausableUpgradeable: _paused
/// 本合约变量:
///   slot N+0: usdc (IERC20)
///   slot N+1: penaltyReceiver (address)
///   slot N+2: balances (mapping)
///   slot N+3: taskCount (mapping)
///   slot N+4: tasks (nested mapping)
///   slot N+5: _nextTaskId (uint256)
///
/// ⚠️ V2 及以后只能**追加**新变量到末尾！
contract StudyStake is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    // ============================================================
    //  状态变量 — 顺序固定，不可更改！
    // ============================================================

    /// @notice 质押代币 (USDC)，V1 部署后不可更改
    IERC20 public usdc;
    /// @notice 惩罚接收地址，由 Owner 动态配置
    address public penaltyReceiver;
    /// @notice 用户总保证金余额
    mapping(address => uint256) public balances;
    /// @notice 用户任务计数器
    mapping(address => uint256) public taskCount;
    /// @notice 用户 => taskId => Task
    mapping(address => mapping(uint256 => Task)) public tasks;
    /// @notice 全局任务 ID 计数器（自增）
    uint256 private _nextTaskId;

    /// @dev 版本标识，升级时递增（用于 reinitializer）
    uint256 public constant VERSION = 1;

    // ============================================================
    //  签到模式
    // ============================================================

    enum CheckInMode { Click, NFC }

    // ============================================================
    //  任务数据结构
    // ============================================================

    enum TaskStatus { Active, Completed, Slashed }

    struct Task {
        uint256 id;           // 任务 ID
        address user;         // 用户地址
        uint256 targetTime;   // 目标到达时间（Unix 时间戳）
        uint256 window;       // 迟到窗口期（秒）
        uint256 penalty;      // 惩罚金额（USDC 精度）
        CheckInMode mode;     // 签到方式：Click 或 NFC
        bytes4 allowedTag;    // NFC 模式下绑定的标签 ID（4字节，足够存 NTAG213 UID）
        TaskStatus status;    // 当前状态
    }

    // ============================================================
    //  事件
    // ============================================================

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event PenaltyReceiverUpdated(
        address indexed oldReceiver,
        address indexed newReceiver
    );
    event TaskCreated(
        uint256 indexed taskId,
        address indexed user,
        uint256 targetTime,
        uint256 window,
        uint256 penalty,
        CheckInMode mode,
        bytes4 allowedTag
    );
    event CheckedIn(uint256 indexed taskId, address indexed user, CheckInMode mode);
    event CheckedInWithNFC(
        uint256 indexed taskId,
        address indexed user,
        bytes4 tagScanned
    );
    event Slashed(
        uint256 indexed taskId,
        address indexed user,
        uint256 penalty
    );

    // ============================================================
    //  构造函数（禁止通过 implementation 直接调用逻辑）
    // ============================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ============================================================
    //  初始化函数（替代构造函数，仅调用一次）
    // ============================================================

    /// @notice 初始化合约
    /// @param _usdc        USDC 合约地址
    /// @param _penaltyAddr 初始惩罚接收地址
    function initialize(
        address _usdc,
        address _penaltyAddr
    ) external reinitializer(uint64(VERSION)) {
        __Ownable_init(msg.sender);
        __Pausable_init();

        require(_usdc != address(0), "Invalid USDC address");
        require(_penaltyAddr != address(0), "Invalid receiver");

        usdc = IERC20(_usdc);
        penaltyReceiver = _penaltyAddr;
    }

    // ============================================================
    //  UUPS 升级权限控制（仅 Owner 可升级）
    // ============================================================

    function _authorizeUpgrade(
        address /*newImplementation*/
    ) internal override onlyOwner {}

    // ============================================================
    //  流程1：资金准备
    // ============================================================

    /// @notice 存入 USDC 作为质押保证金
    /// @param amount 存入金额（需先 approve 合约地址）
    function deposit(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be > 0");

        bool ok = usdc.transferFrom(msg.sender, address(this), amount);
        require(ok, "USDC transfer failed");

        balances[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    /// @notice 提取未锁定的剩余余额
    /// @param amount 提取金额
    function withdraw(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be > 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        uint256 locked = _getLockedBalance(msg.sender);
        require(
            balances[msg.sender] - locked >= amount,
            "Balance locked by active tasks"
        );

        balances[msg.sender] -= amount;

        bool ok = usdc.transfer(msg.sender, amount);
        require(ok, "USDC transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice 查看用户当前可提取的可用余额
    function availableBalance(
        address user
    ) external view returns (uint256) {
        uint256 locked = _getLockedBalance(user);
        return balances[user] > locked ? balances[user] - locked : 0;
    }

    // ============================================================
    //  Owner 权限：修改惩罚接收地址
    // ============================================================

    /// @notice 更新惩罚资金接收地址（仅 Owner）
    function setPenaltyReceiver(address _receiver) external onlyOwner {
        require(_receiver != address(0), "Invalid receiver");
        emit PenaltyReceiverUpdated(penaltyReceiver, _receiver);
        penaltyReceiver = _receiver;
    }

    // ============================================================
    //  流程2：设定目标（支持选择签到方式）
    // ============================================================

    /// @dev 内部核心逻辑 — 创建任务（所有参数已校验）
    function _createTaskInternal(
        uint256 targetTime,
        uint256 window,
        uint256 penalty,
        CheckInMode mode,
        bytes4 tagId
    ) internal returns (uint256 taskId) {
        require(targetTime > block.timestamp, "Target must be in future");
        require(window > 0, "Window must be > 0");
        require(penalty > 0, "Penalty must be > 0");
        require(
            balances[msg.sender] >= penalty + _getLockedBalance(msg.sender),
            "Insufficient deposit for penalty"
        );

        if (mode == CheckInMode.NFC) {
            require(tagId != bytes4(0), "NFC requires a valid tag");
        } else {
            tagId = bytes4(0);
        }

        taskId = ++_nextTaskId;
        tasks[msg.sender][taskId] = Task({
            id: taskId,
            user: msg.sender,
            targetTime: targetTime,
            window: window,
            penalty: penalty,
            mode: mode,
            allowedTag: tagId,
            status: TaskStatus.Active
        });

        taskCount[msg.sender]++;
        emit TaskCreated(taskId, msg.sender, targetTime, window, penalty, mode, tagId);
    }

    /// @notice 创建签到任务（完整参数版本）
    function createTask(
        uint256 targetTime,
        uint256 window,
        uint256 penalty,
        CheckInMode mode,
        bytes4 tagId
    ) external whenNotPaused returns (uint256 taskId) {
        return _createTaskInternal(targetTime, window, penalty, mode, tagId);
    }

    // ============================================================
    //  流程3a：履约签到 — 点击模式
    // ============================================================

    /// @notice 点击签到（仅适用于 Click 模式的任务）
    /// @param taskId 任务 ID
    function checkIn(uint256 taskId) external whenNotPaused {
        Task storage t = tasks[msg.sender][taskId];
        require(t.user == msg.sender, "Not your task");
        require(t.status == TaskStatus.Active, "Task not active");
        require(
            t.mode == CheckInMode.Click,
            "This task requires NFC check-in"
        ); // 🔒 关键校验：NFC 任务不能用点的方式签！

        _validateTimeWindow(t);

        t.status = TaskStatus.Completed;
        emit CheckedIn(taskId, msg.sender, CheckInMode.Click);
    }

    // ============================================================
    //  流程3b：履约签到 — NFC 模式
    // ============================================================

    /// @notice NFC 签到（必须传入正确的 Tag ID）
    /// @param taskId     任务 ID
    /// @param scannedTag 手机扫描到的 NFC 标签 ID
    function checkInWithNFC(
        uint256 taskId,
        bytes4 scannedTag
    ) external whenNotPaused {
        Task storage t = tasks[msg.sender][taskId];
        require(t.user == msg.sender, "Not your task");
        require(t.status == TaskStatus.Active, "Task not active");
        require(
            t.mode == CheckInMode.NFC,
            "This task is click-only mode"
        );
        require(scannedTag == t.allowedTag, "Wrong NFC tag"); // 🏷️ 核心防作弊

        _validateTimeWindow(t);

        t.status = TaskStatus.Completed;
        emit CheckedInWithNFC(taskId, msg.sender, scannedTag);
    }

    // ============================================================
    //  流程4：违约清算（可由任何人触发）
    // ============================================================

    /// @notice 触发违约清算，扣除惩罚金转至惩罚地址
    /// @param user   目标用户地址
    /// @param taskId 任务 ID
    function slash(
        address user,
        uint256 taskId
    ) external whenNotPaused {
        Task storage t = tasks[user][taskId];
        require(t.status == TaskStatus.Active, "Task not active");
        require(
            block.timestamp > t.targetTime + t.window,
            "Still within window"
        );

        t.status = TaskStatus.Slashed;
        balances[user] -= t.penalty;

        bool ok = usdc.transfer(penaltyReceiver, t.penalty);
        require(ok, "USDC transfer failed");

        emit Slashed(taskId, user, t.penalty);
    }

    // ============================================================
    //  Pausable（紧急暂停）
    // ============================================================

    /// @notice 暂停所有操作（仅 Owner）— 用于安全紧急情况
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice 取消暂停（仅 Owner）
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============================================================
    //  内部函数
    // ============================================================

    /// @notice 校验是否在时间窗内
    function _validateTimeWindow(Task storage t) internal view {
        uint256 deadline = t.targetTime + t.window;
        require(block.timestamp >= t.targetTime, "Too early to check in");
        require(block.timestamp <= deadline, "Window expired - too late");
    }

    /// @notice 计算用户被进行中任务锁定的总额
    function _getLockedBalance(
        address user
    ) internal view returns (uint256 locked) {
        uint256 count = taskCount[user];
        for (uint256 i = 1; i <= count; i++) {
            if (tasks[user][i].status == TaskStatus.Active) {
                locked += tasks[user][i].penalty;
            }
        }
    }

    // ============================================================
    //  便捷函数（放在末尾避免前向引用问题）
    // ============================================================

    /// @notice 创建纯点击签到任务的便捷函数（默认 Click 模式）
    function createSimpleTask(
        uint256 targetTime,
        uint256 window,
        uint256 penalty
    ) external returns (uint256) {
        return _createTaskInternal(targetTime, window, penalty, CheckInMode.Click, bytes4(0));
    }
}
