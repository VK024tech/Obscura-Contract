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

import {MerkleTreeWithHistory} from "./MerkleTreeWithHistory.sol";
import {IVerifier} from "./Interfaces";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";

contract Obscura is MerkleTreeWithHistory, ReentrancyGuard {
    error Obscura__Invalid_Amount();
    error Obscura__Commitment_Already_Exist();
    error Obscura__Invalid_Root();
    error Obscura__NullifierHash_Already_Used();
    error Obscura__TransferFailed();
    error Obscura__InvalidProof();
    error Obscura__Fee_Too_High();
    error Obscura__Invalid_Relayer();
    error Obscura__Invalid_Recipient();
    error Obscura__Only_Relayer_Can_Call();

    uint256 public constant DEPOSIT_AMOUNT = 1 ether;
    uint256 public constant TREE_DEPTH = 20;
    uint256 public constant FEE_BPS = 20; // 0.2%
    address public feeCollector;

    mapping(bytes32 => bool) public commitments;
    mapping(uint256 => bool) public nullifierHashes;

    IVerifier public verifier;

    event Deposit(bytes32 commitment, uint32 leafIndex, string cid);
    event Withdrawal(address recipient, uint256 nullifierHash, address relayer);

    constructor(address _verifier, address _feeCollector) MerkleTreeWithHistory(TREE_DEPTH) {
        verifier = IVerifier(_verifier);
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

    function withdraw(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256 root,
        uint256 nullifierHash,
        address payable recipient,
        address payable relayer,
        uint256 relayerFee
    ) external nonReentrant {
        // only relayer can call
        require(msg.sender == relayer, Obscura__Only_Relayer_Can_Call());
        // validate correct root
        require(isKnownRoot(root), Obscura__Invalid_Root());
        // validate nullifier hash to prevent double withdrawal
        require(!nullifierHashes[nullifierHash], Obscura__NullifierHash_Already_Used());
        // validate relayer address
        require(relayer != address(0), Obscura__Invalid_Relayer());
        // validate recipient address
        require(recipient != address(0), Obscura__Invalid_Recipient());

        // transfer amount
        uint256 protocol_fee = calculateFee(DEPOSIT_AMOUNT);
        uint256 amountAfterProtocol = DEPOSIT_AMOUNT - protocol_fee;
        uint256 finalAmount = amountAfterProtocol - relayerFee;
        // prepare public inputs
        uint256[5] memory publicInputs =
            [root, nullifierHash, uint256(uint160(recipient)), uint256(uint160(relayer)), relayerFee];

        // verify zk proof
        require(verifier.verifyProof(_pA, _pB, _pC, publicInputs), Obscura__InvalidProof());
        // make nullifier as used
        nullifierHashes[nullifierHash] = true;
        require(relayerFee < DEPOSIT_AMOUNT - protocol_fee, Obscura__Fee_Too_High());
        // send final amount to recipient
        (bool success,) = recipient.call{value: finalAmount}("");
        if (!success) {
            revert Obscura__TransferFailed();
        }
        // deduct relayer fee
        (bool relayerSuccess,) = relayer.call{value: relayerFee}("");
        if (!relayerSuccess) {
            revert Obscura__TransferFailed();
        }
        // deduct protocol fee
        (bool feeSuccess,) = payable(feeCollector).call{value: protocol_fee}("");
        if (!feeSuccess) {
            revert Obscura__TransferFailed();
        }

        emit Withdrawal(recipient, nullifierHash, relayer);
    }

    function calculateFee(uint256 amount) internal pure returns (uint256 fee) {
        fee = (amount * FEE_BPS) / 10_000;
    }
}
