// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/PoseidonHasher.sol";

contract DeployHasher is Script {
    function run() external {
        vm.startBroadcast();

        PoseidonHasher hasher = new PoseidonHasher();

        vm.stopBroadcast();
    }
}