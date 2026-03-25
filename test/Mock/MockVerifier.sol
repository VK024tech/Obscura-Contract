// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockVerifier {
    bool public shouldVerify = true;

    function setVerify(bool _value) external {
        shouldVerify = _value;
    }

    function verifyProof(uint256[2] calldata, uint256[2][2] calldata, uint256[2] calldata, uint256[3] calldata)
        external
        view
        returns (bool)
    {
        return shouldVerify;
    }
}
