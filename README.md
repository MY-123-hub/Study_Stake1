# StudyStake (自律质押协议)

基于 Web3 智能合约的个人目标强制执行 DApp — **UUPS 可升级版本 + NFC 双签到模式**

## 核心逻辑

用户质押 USDC → 设定目标时间窗口 → **按时签到保留资金** / **逾期扣罚**

**支持两种签到方式：**
- 🖱️ **Click 模式** — 纯点击签到（适合轻量任务）
- 📱 **NFC 模式** — 必须触碰指定 NFC 标签才能签到（防作弊，如图书馆打卡）

## 技术栈

| 组件 | 技术 |
|------|------|
| 智能合约 | Solidity ^0.8.20 + OpenZeppelin v5 (Upgradeable) |
| 开发框架 | Foundry (forge + anvil) |
| 升级模式 | **UUPS Proxy** (ERC1967Proxy + UUPSUpgradeable) |
| 测试 | Forge Tests (**39/39 passed ✅**) |
| 代币 | USDC (IERC20) |

## 项目结构

```
StudyStake/
├── src/
│   └── StudyStake.sol    # 核心可升级合约 (Implementation)
├── test/
│   └── StudyStake.t.sol   # 37 个测试用例（含 NFC 双模式 + 升级测试）
├── script/
│   └── Deploy.sol         # 部署脚本 (Impl + Proxy)
├── lib/
│   ├── forge-std/                    # Foundry 测试工具
│   ├── openzeppelin-contracts/        # OZ 基础合约
│   └── openzeppelin-contracts-upgradeable/  # OZ 可升级合约
├── .env.example         # 环境变量模板
└── foundry.toml         # Foundry 配置
```

## 架构设计：UUPS 代理模式

```
                    ┌─────────────────────────┐
                    │   ERC1967Proxy          │ ◄── 用户始终与这个地址交互
                    │   (地址永远不变)          │     存储所有状态数据
                    │                         │
                    │  implementation: ───────┼──► Implementation V1
                    └─────────────────────────┘      (StudyStake.sol)
                                                          │
                                                    upgradeTo()
                                                          │
                                                          ▼
                                                  Implementation V2
                                                  (未来: 新功能)
```

### 为什么选 UUPS？

| 特性 | UUPS | Transparent Proxy |
|------|------|-------------------|
| Gas 消耗 | **低** | 较高 |
| 升级权限 | 在实现合约中控制 | 在代理合约中 |
| 行业标准 | ✅ 是 (OZ 推荐) | 较旧版 |
| 合约大小 | 小 | 大 |

### 存储布局规则（⚠️ 升级关键）

```
Slot N+0: usdc           (IERC20)
Slot N+1: penaltyReceiver (address)
Slot N+2: balances       (mapping)
Slot N+3: taskCount      (mapping)
Slot N+4: tasks          (nested mapping → Task struct)
Slot N+5: _nextTaskId    (uint256)

Task 结构体 (8 字段):
  id, user, targetTime, window, penalty,
  mode (CheckInMode enum), allowedTag (bytes4), status (TaskStatus enum)
```

> ⚠️ V2/V3 只能**追加**新变量到末尾，不能删除或修改已有变量的顺序！

## 核心功能

### 5 大业务流

1. **Deposit (存入)** — 质押 USDC 作为保证金
2. **Create Task (设定目标)** — 设置目标时间、窗口期、惩罚金额、**签到模式**
3. **CheckIn (签到)** — 窗口期内签到，任务完成
   - `checkIn(taskId)` — Click 模式签到
   - `checkInWithNFC(taskId, tagId)` — NFC 模式签到（需匹配标签 ID）
4. **Slash (清算)** — 逾期自动扣除惩罚金至配置地址
5. **Withdraw (提现)** — 提取未锁定的剩余资金

### 双签到模式详解

#### Click 模式（默认）
```solidity
stake.createSimpleTask(targetTime, window, penalty);
// 或显式指定:
stake.createTask(targetTime, window, penalty, CheckInMode.Click, bytes4(0));
```
- 用户在窗口期内调用 `checkIn(taskId)` 即可完成
- `allowedTag` 自动设为 `0x00000000`
- 传入非零 tag 会被强制归零

#### NFC 模式（防作弊）
```solidity
stake.createTask(targetTime, window, penalty, CheckInMode.NFC, 0xA1B2C3D4);
```
- 创建时必须提供有效的 `tagId`（NFC 标签 ID）
- 签到时必须调用 `checkInWithNFC(taskId, tagId)`，且 tagId 必须匹配
- **NFC 任务不能用 `checkIn()` 完成！**（安全核心）
- **Click 任务也不能用 `checkInWithNFC() 完成！**
- 适用场景：图书馆座位打卡、实验室门禁验证等需要物理在场证明的场景

### 安全特性

- 🔒 **资金锁定**: 进行中任务的惩罚金额不可提取
- 🔐 **NFC 防作弊**: NFC 任务必须匹配标签 ID，防止远程代签
- ⚙️ **动态惩罚地址**: Owner 可随时修改资金去向
- 🔄 **UUPS 可升级**: 仅 Owner 可升级 Implementation
- 🛑 **紧急暂停**: Pausable 机制应对安全紧急情况
- 📦 **Ownable**: 权限管理

## 快速开始

### 前置条件

```bash
# Foundry (已安装于 WSL):
export PATH=$PATH:$HOME/.foundry/bin
```

### 编译

```bash
cd StudyStake
forge build
```

### 运行测试

```bash
forge test -vvv
# 结果: 37 passed; 0 failed; 0 skipped (StudyStakeTest) ✅
#       2 passed; 0 failed; 0 skipped (CounterTest)
# 总计: 39 passed ✅
```

### 本地部署 (Anvil)

```bash
# 终端 1: 启动本地链
anvil

# 终端 2: 部署
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --private-key <ANVIL_KEY_0> \
  -vvv
```

### 部署到 Sepolia 测试网

```bash
# 1. 复制环境变量模板
cp .env.example .env
# 编辑 .env，填入真实值

# 2. 部署
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $RPC_URL \
  --broadcast \
  -vvv
```

## 升级指南

当需要部署新功能时：

```solidity
// V2 示例
contract StudyStakeV2 is StudyStake {
    // 新增变量追加到末尾！
    address public feeCollector;
    uint256 public version = 2;

    function initializeV2(address _feeCollector) external reinitializer(2) {
        __Pausable_init();
        feeCollector = _feeCollector;
    }
}
```

```bash
# 升级命令
forge script script/Upgrade.s.sol:UpgradeScript \
  --rpc-url $RPC_URL \
  --broadcast \
  --script-args <PROXY_ADDRESS> <NEW_IMPL_ADDRESS>
```

## 测试覆盖

| 模块 | 用例数 | 说明 |
|------|--------|------|
| 初始化 & 升级 | 4 | init, reinit, upgrade auth, successful upgrade |
| Pausable | 1 | pause/unpause |
| 存入/提现 | 5 | deposit, withdraw, 锁定余额, availableBalance |
| Owner 权限 | 2 | setPenaltyReceiver |
| 创建任务 — Click | 6 | 完整字段验证、便捷函数、时间校验、多任务 |
| 创建任务 — NFC | 3 | 有效 tag、无效 tag 强制归零、混合模式 |
| 点击签到 | 4 | 成功、准时、太早、太晚 |
| **NFC 安全核心** | **5** | **NFC拒绝click、成功、错误tag、反向限制、权限** |
| 违约清算 | 3 | 扣款(双模式)、重复调用、窗口期内 |
| 完整流程 — Click happy path | 1 | 存入→创建→签到→提现全流程 |
| 完整流程 — NFC happy path | 1 | 存入→NFC创建→NFC签到→提现 |
| 完整流程 — NFC fail path | 1 | 存入→NFC创建→超时→清算→提现 |
| 数据持久化 | 1 | **升级后数据不丢失（含 NFC 字段）** |

**总计: 37 个 StudyStake 测试用例 + 2 个 Counter = 39 个测试全部通过** ✅

### 关键安全测试

- `test_nfc_task_rejects_click_checkin` — NFC 任务不能用普通 checkIn 绕过 ✅
- `test_nfc_checkin_wrong_tag_rejected` — 错误标签被拒绝 ✅
- `test_nfc_checkin_only_works_on_nfc_tasks` — click 任务不能调 checkInWithNFC ✅
- `test_data_persists_after_upgrade` — UUPS 升级后所有数据（含 mode/tag）完好 ✅

## License

MIT
