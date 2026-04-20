// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/StudyStake.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title 部署 StudyStake UUPS 可升级合约
/// @notice 分两步：1) Deploy Implementation  2) Deploy Proxy + Initialize
///
/// 用法:
///   forge script script/Deploy.s.sol:DeployScript \
///     --rpc-url <RPC> --broadcast -vvv
///   (需在 .env 中定义 PRIVATE_KEY, USDC_ADDRESS, PENALTY_RECEIVER)
contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address usdcAddr = vm.envAddress("USDC_ADDRESS");
        address penaltyReceiver = vm.envAddress("PENALTY_RECEIVER");

        vm.startBroadcast(deployerPrivateKey);

        // ====== Step 1: 部署 Implementation 合约 ======
        StudyStake implementation = new StudyStake();
        console.log("Implementation deployed to:", address(implementation));

        // ====== Step 2: 部署 Proxy 并初始化 ======
        bytes memory initData = abi.encodeWithSelector(
            StudyStake.initialize.selector,
            usdcAddr,
            penaltyReceiver
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        console.log("Proxy deployed to:", address(proxy));

        // 包装为 StudyStake 接口以便交互
        StudyStake stake = StudyStake(payable(address(proxy)));

        // 验证初始化
        console.log("USDC address:");
        console.logAddress(address(stake.usdc()));
        console.log("Penalty Receiver:");
        console.logAddress(stake.penaltyReceiver());
        console.log("Owner:");
        console.logAddress(stake.owner());
        console.log("Version:", stake.VERSION());

        vm.stopBroadcast();

        console.log("Deployment complete!");
        console.log("   Proxy (user-facing addr):", address(proxy));
        console.log("   Implementation:", address(implementation));
    }
}
