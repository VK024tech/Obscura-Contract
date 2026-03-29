// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHasher} from "../../src/MerkleTreeWithHistory.sol";

contract MockHasher is IHasher {
    function hash(bytes32 left, bytes32 right)
        external
        pure
        override
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(left, right));
    }
}