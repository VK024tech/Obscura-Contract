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

contract Obscura {
    error Obscura__Invalid_Amount();
    error Obscura__Commitment_Already_Exist();

    uint256 public constant DEPOSIT_AMOUNT = 1 ether;
    mapping (bytes32 => bool) commitments;


    function deposit(bytes32 commitment) external payable {
        // validation to check
        require(msg.value == DEPOSIT_AMOUNT, Obscura__Invalid_Amount());
        require(!commitments[commitment], Obscura__Commitment_Already_Exist());

        // make commitment true
        commitments[commitment] = true;

        


    }

    function withdraw() public {

    }
}