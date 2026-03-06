// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Groth16Verifier} from "./Verifier.sol";
import {MerkleTreeWithHistory} from "./MerkleTreeWithHistory.sol";

contract Obscura is MerkleTreeWithHistory {
    error Obscura__Invalid_Amount();
    error Obscura__Commitment_Already_Exist();

    uint256 public constant DEPOSIT_AMOUNT = 1 ether;
    uint256 public constant TREE_DEPTH = 20;
    uint256 public constant FEE_BPS = 20; // 0.2%
    address public feeCollector;

    mapping(uint256 => bool) public commitments;
    mapping(uint256 => bool) public nullifierHashes;

    mapping(uint256 => bool) public roots;
    uint256 public currentRoot;

    IVerifier public verifier;

    event Deposit(uint256 commitment, uint32 leafIndex, string cid);

    constructor(address _verifier, address _feeCollector) MerkleTreeWithHistory(TREE_DEPTH) {
        Verifier = IVerifier(_verifier);
        feeCollector = _feeCollector;
    }

    function deposit(bytes32 commitment, string calldata cid) external payable {
        // validate required amount
        require(msg.value == DEPOSIT_AMOUNT, Obscura__Invalid_Amount());
        // validate unique commitment
        require(!commitments[commitment], Obscura__Commitment_Already_Exist());

        // make commitment true
        commitments[commitment] = true;

        // insert the commitment into merkle tree
        uint32 leafIndex = _insert(commitment);

        // emit event for reciever
        emit Deposit(commitment, leafIndex, cid);
    }

    function withdraw() public {}
}
