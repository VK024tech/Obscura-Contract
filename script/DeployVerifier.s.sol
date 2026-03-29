// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/Verifier.sol";

contract DeployVerifier is Script {
    function run() external {
        vm.startBroadcast();

        Groth16Verifier verifier = new Groth16Verifier();

          console2.log("Verifier deployed at:", address(verifier));

        vm.stopBroadcast();
    }
}