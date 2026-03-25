// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHasher} from "../../src/MerkleTreeWithHistory.sol";

contract MockHasher is IHasher {
    uint256 constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function MiMCSponge(uint256 xL, uint256 xR)
        external
        pure
        override
        returns (uint256, uint256)
    {
        uint256 hash = uint256(keccak256(abi.encodePacked(xL, xR))) % FIELD_SIZE;
        return (hash, 0);
    }
}