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
    error Obscura__Invalid_Root();
    error Obscura__NullifierHash_Already_Used();
    error Obscura__TransferFailed();

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
    event Withdrawal(address recipient, uint256 nullifierHash);

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

    function withdraw(bytes calldata proof, uint256 root, uint256 nullifierHash, address payable recipient) external {
        // validate correct root
        require(!roots[root], Obscura__Invalid_Root());
        // validate nullifier hash to prevent double withdrawal
        require(!nullifierHashes[nullifierHash], Obscura__NullifierHash_Already_Used());
        // prepare public inputs
        uint256[3] memory publicInputs = [
            root,
            nullifierHash,
            uint256(uint160(recipient))
        ]
        // verify zk proof
        require(verifier.verifyProof(proof, publicInputs));
        // make nullifier as used
        nullifierHashes[nullifierHash] = true;
        // transfer amount
        uint256 amountToSend = DEPOSIT_AMOUNT - calculateFee(DEPOSIT_AMOUNT);
        (bool success,) = payable(recipient).call{value: amountToSend}("");
        if(!success){
            revert Obscura__TransferFailed();
        }
        emit withdrawal(recipient, nullifierHash);
    }

    function calculateFee(uint256 amount) external pure returns (uint256 fee){
        fee = (amount * FEE_BPS) / 10_000;
    }
}
