// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHasher} from "./MerkleTreeWithHistory.sol";
import {PoseidonT3} from "poseidon-solidity/PoseidonT3.sol";

contract PoseidonHasher is IHasher {
    function hash(bytes32 left, bytes32 right) external pure override returns (bytes32) {
        return bytes32(
            PoseidonT3.hash([
                uint256(left),
                uint256(right)
            ])
        );
    }
}