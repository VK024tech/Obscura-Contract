// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Obscura} from "../src/Obscura.sol";

contract DeployObscura is Script {
    function run() external {
        vm.startBroadcast();

        address verifier = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        address hasher = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
        address feeCollector = msg.sender;

        Obscura obscura = new Obscura(verifier, feeCollector, hasher);
        vm.stopBroadcast();
    }
}
