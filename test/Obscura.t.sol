pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Obscura} from "../src/Obscura.sol";
import {MockVerifier} from "./Mock/MockVerifier.sol";
import {MockHasher} from "./Mock/MockHasher.sol";
import {PoseidonT6} from "../lib/poseidon-solidity/contracts/PoseidonT6.sol";

contract ObscuraTest is Test {
    Obscura obscura;
    MockVerifier verifier;

    address user = address(1);
    address user_02 = address(2);
    address relayer = address(3);
    address recipient = address(4);
    address feeCollector = address(5);

    uint256 constant DEPOSIT_AMOUNT = 1 ether;

    function setUp() public {
        verifier = new MockVerifier();

        MockHasher hasher = new MockHasher();
        obscura = new Obscura(address(verifier), feeCollector, address(hasher));

        vm.deal(user, 10 ether);
        vm.deal(user_02, 10 ether);
        vm.deal(relayer, 10 ether);
    }

    function _deposit(address _user) internal returns (bytes32 commitment, bytes32 root) {
        uint256 rawCommitment = uint256(keccak256(abi.encodePacked("test"))) % FIELD_SIZE_01;

        commitment = bytes32(rawCommitment);

        vm.prank(_user);
        obscura.deposit{value: 1 ether}(commitment, "cid");

        root = obscura.getLastRoot();
    }

    function _getWithdrawInputs(bytes32 root)
        internal
        view
        returns (
            uint256[2] memory _pA,
            uint256[2][2] memory _pB,
            uint256[2] memory _pC,
            uint256 nullifierHash,
            uint256 relayerFee,
            uint256 signalHash
        )
    {
        nullifierHash = 123;
        relayerFee = 0;

        signalHash = PoseidonT6.hash(
            [
                uint256(uint160(recipient)),
                uint256(uint160(relayer)),
                relayerFee,
                block.chainid,
                uint256(uint160(address(obscura)))
            ]
        );
    }

    function _withdraw(bytes32 root, uint256 nullifierHash, uint256 relayerFee, uint256 signalHash) internal {
        uint256[2] memory _pA;
        uint256[2][2] memory _pB;
        uint256[2] memory _pC;

        vm.prank(relayer);

        obscura.withdraw(
            _pA, _pB, _pC, uint256(root), nullifierHash, payable(recipient), payable(relayer), relayerFee, signalHash
        );
    }

    // -----------------------
    // DEPOSIT TESTS
    // -----------------------
    uint256 FIELD_SIZE_01 = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 FIELD_SIZE_02 = 57352954631839275222246405745257275088548364400416034343698204186575808495783;
    event Deposit(bytes32 commitment, uint32 leafIndex, string cid);

    function testDepositSuccess() public {
        uint256 rawCommitment = uint256(keccak256(abi.encodePacked("test"))) % FIELD_SIZE_01;

        bytes32 commitment = bytes32(rawCommitment);

        vm.prank(user);
        obscura.deposit{value: DEPOSIT_AMOUNT}(commitment, "cid");

        assertTrue(obscura.commitments(commitment));
    }

    function testDepositMultipleWithSameUser() public {
        uint256 rawCommitment_01 = uint256(keccak256(abi.encodePacked("test01"))) % FIELD_SIZE_01;
        bytes32 commitment_01 = bytes32(rawCommitment_01);
        uint256 rawCommitment_02 = uint256(keccak256(abi.encodePacked("test02"))) % FIELD_SIZE_02;
        bytes32 commitment_02 = bytes32(rawCommitment_02);

        vm.prank(user);
        obscura.deposit{value: DEPOSIT_AMOUNT}(commitment_01, "cid");
        vm.prank(user);
        obscura.deposit{value: DEPOSIT_AMOUNT}(commitment_02, "cid");

        assertTrue(obscura.commitments(commitment_01));
        assertTrue(obscura.commitments(commitment_02));
    }

    function testDepositMultipleWithDifferentUser() public {
        uint256 rawCommitment_01 = uint256(keccak256(abi.encodePacked("test01"))) % FIELD_SIZE_01;
        bytes32 commitment_01 = bytes32(rawCommitment_01);
        uint256 rawCommitment_02 = uint256(keccak256(abi.encodePacked("test02"))) % FIELD_SIZE_02;
        bytes32 commitment_02 = bytes32(rawCommitment_02);

        vm.prank(user);
        obscura.deposit{value: DEPOSIT_AMOUNT}(commitment_01, "cid");
        vm.prank(user_02);
        obscura.deposit{value: DEPOSIT_AMOUNT}(commitment_02, "cid");

        assertTrue(obscura.commitments(commitment_01));
        assertTrue(obscura.commitments(commitment_02));
    }

    function testDepositDuplicateCommitment() public {
        uint256 rawCommitment_01 = uint256(keccak256(abi.encodePacked("test01"))) % FIELD_SIZE_01;
        bytes32 commitment_01 = bytes32(rawCommitment_01);

        vm.prank(user);
        obscura.deposit{value: DEPOSIT_AMOUNT}(commitment_01, "cid");

        vm.prank(user);
        vm.expectRevert(Obscura.Obscura__Commitment_Already_Exist.selector);
        obscura.deposit{value: DEPOSIT_AMOUNT}(commitment_01, "cid");
    }

    function testDepositInvalidAmount() public {
        uint256 rawCommitment = uint256(keccak256(abi.encodePacked("test"))) % FIELD_SIZE_01;

        bytes32 commitment = bytes32(rawCommitment);

        vm.prank(user);
        vm.expectRevert(Obscura.Obscura__Invalid_Amount.selector);
        obscura.deposit{value: 2 ether}(commitment, "cid");
    }

    function testDepositEmitsEvent() public {
        uint256 rawCommitment = uint256(keccak256(abi.encodePacked("test"))) % FIELD_SIZE_01;
        bytes32 commitment = bytes32(rawCommitment);
        string memory cid = "cid";
        vm.prank(user);
        vm.expectEmit(false, false, false, false);
        emit Deposit(commitment, 0, cid);
        obscura.deposit{value: 1 ether}(commitment, cid);
    }

    function testDepositUpdatesBalance() public {
        uint256 balanceBefore = address(obscura).balance;
        uint256 rawCommitment = uint256(keccak256(abi.encodePacked("test"))) % FIELD_SIZE_01;

        bytes32 commitment = bytes32(rawCommitment);

        vm.prank(user);
        obscura.deposit{value: DEPOSIT_AMOUNT}(commitment, "cid");
        uint256 balanceAfter = address(obscura).balance;
        assertEq(balanceAfter, balanceBefore + 1 ether);
    }

    // -----------------------
    // WITHDRAWAL TESTS
    // -----------------------

    function testWithdrawalSuccess() public {
        (bytes32 commitment, bytes32 root) = _deposit(user);

        (,,, uint256 nullifierHash, uint256 relayerFee, uint256 signalHash) = _getWithdrawInputs(root);

        uint256 beforeBalance = recipient.balance;

        _withdraw(root, nullifierHash, relayerFee, signalHash);

        assertTrue(obscura.nullifierHashes(nullifierHash));
        assertGt(recipient.balance, beforeBalance);
    }

    function testWithdrawalInvalidProof() public {
        (, bytes32 root) = _deposit(user);

        (,,, uint256 nullifierHash, uint256 relayerFee, uint256 signalHash) = _getWithdrawInputs(root);

        MockVerifier(address(verifier)).setVerify(false);

        vm.expectRevert(Obscura.Obscura__InvalidProof.selector);

        _withdraw(root, nullifierHash, relayerFee, signalHash);
    }

    function testWithdrawalDoubleSpending() public {
        (, bytes32 root) = _deposit(user);

        (,,, uint256 nullifierHash, uint256 relayerFee, uint256 signalHash) = _getWithdrawInputs(root);

        _withdraw(root, nullifierHash, relayerFee, signalHash);
        vm.expectRevert(Obscura.Obscura__NullifierHash_Already_Used.selector);
        _withdraw(root, nullifierHash, relayerFee, signalHash);
    }

    function testWithdrawalInvalidRoot() public {
        (, bytes32 root) = _deposit(user);
        uint256 invalidRoot = uint256(keccak256("fake"));

        (,,, uint256 nullifierHash, uint256 relayerFee, uint256 signalHash) = _getWithdrawInputs(root);

        vm.expectRevert(Obscura.Obscura__Invalid_Root.selector);
        _withdraw(bytes32(invalidRoot), nullifierHash, relayerFee, signalHash);
    }

    function testWithdrawalWrongSignalHash() public {
        (, bytes32 root) = _deposit(user);

        (,,, uint256 nullifierHash, uint256 relayerFee, uint256 correctSignalHash) = _getWithdrawInputs(root);

        uint256 wrongSignalHash = correctSignalHash + 1;

        uint256[2] memory _pA;
        uint256[2][2] memory _pB;
        uint256[2] memory _pC;

        vm.prank(relayer);

        vm.expectRevert(Obscura.Obscura__Invalid_Signal.selector);

        obscura.withdraw(
            _pA,
            _pB,
            _pC,
            uint256(root),
            nullifierHash,
            payable(recipient),
            payable(relayer),
            relayerFee,
            wrongSignalHash
        );
    }

    function testWithdrawalFeeDistribution() public {
        (, bytes32 root) = _deposit(user);

        uint256 relayerFee = 0.01 ether;

        (,,, uint256 nullifierHash,,) = _getWithdrawInputs(root);

        uint256 signalHash = PoseidonT6.hash(
            [
                uint256(uint160(recipient)),
                uint256(uint160(relayer)),
                relayerFee,
                block.chainid,
                uint256(uint160(address(obscura)))
            ]
        );

        uint256 recipientBefore = recipient.balance;
        uint256 relayerBefore = relayer.balance;
        uint256 feeCollectorBefore = feeCollector.balance;

        vm.prank(relayer);
        obscura.withdraw(
            [uint256(0), uint256(0)],
            [[uint256(0), uint256(0)], [uint256(0), uint256(0)]],
            [uint256(0), uint256(0)],
            uint256(root),
            nullifierHash,
            payable(recipient),
            payable(relayer),
            relayerFee,
            signalHash
        );

        uint256 protocolFee = (1 ether * 20) / 10_000;
        uint256 expectedRecipient = 1 ether - protocolFee - relayerFee;

        assertEq(recipient.balance, recipientBefore + expectedRecipient);
        assertEq(relayer.balance, relayerBefore + relayerFee);
        assertEq(feeCollector.balance, feeCollectorBefore + protocolFee);
    }

    function testWithdrawalRelayerNotCaller() public {
        (, bytes32 root) = _deposit(user);

        (,,, uint256 nullifierHash,,) = _getWithdrawInputs(root);

        uint256 relayerFee = 0;

        uint256 signalHash = PoseidonT6.hash(
            [
                uint256(uint160(recipient)),
                uint256(uint160(relayer)),
                relayerFee,
                block.chainid,
                uint256(uint160(address(obscura)))
            ]
        );

        address attacker = address(999);

        vm.prank(attacker);

        uint256[2] memory _pA;
        uint256[2][2] memory _pB;
        uint256[2] memory _pC;

        vm.expectRevert(Obscura.Obscura__Only_Relayer_Can_Call.selector);
        obscura.withdraw(
            _pA, _pB, _pC, uint256(root), nullifierHash, payable(recipient), payable(relayer), relayerFee, signalHash
        );
    }

    // -----------------------
    // EDGE TESTS
    // -----------------------

    function testWithdrawalWithZeroFee() public {
        (, bytes32 root) = _deposit(user);

        (,,, uint256 nullifierHash,,) = _getWithdrawInputs(root);

        uint256 relayerFee = 0;

        uint256 signalHash = PoseidonT6.hash(
            [
                uint256(uint160(recipient)),
                uint256(uint160(relayer)),
                relayerFee,
                block.chainid,
                uint256(uint160(address(obscura)))
            ]
        );

        uint256 recipientBefore = recipient.balance;
        uint256 relayerBefore = relayer.balance;

        uint256[2] memory _pA;
        uint256[2][2] memory _pB;
        uint256[2] memory _pC;

        vm.prank(relayer);
        obscura.withdraw(
            _pA, _pB, _pC, uint256(root), nullifierHash, payable(recipient), payable(relayer), relayerFee, signalHash
        );

        uint256 protocolFee = (1 ether * 20) / 10_000;
        uint256 expectedRecipient = 1 ether - protocolFee;

        assertEq(recipient.balance, recipientBefore + expectedRecipient);
        assertEq(relayer.balance, relayerBefore);
    }

    function testWithdrawalWithHighFee() public {
        (, bytes32 root) = _deposit(user);

        (,,, uint256 nullifierHash,,) = _getWithdrawInputs(root);

        uint256 protocolFee = (1 ether * 20) / 10_000;
        uint256 amountAfterProtocol = 1 ether - protocolFee;

        uint256 relayerFee = amountAfterProtocol;

        uint256 signalHash = PoseidonT6.hash(
            [
                uint256(uint160(recipient)),
                uint256(uint160(relayer)),
                relayerFee,
                block.chainid,
                uint256(uint160(address(obscura)))
            ]
        );

        uint256[2] memory _pA;
        uint256[2][2] memory _pB;
        uint256[2] memory _pC;

        vm.prank(relayer);
        vm.expectRevert(Obscura.Obscura__Fee_Too_High.selector);

        obscura.withdraw(
            _pA, _pB, _pC, uint256(root), nullifierHash, payable(recipient), payable(relayer), relayerFee, signalHash
        );
    }

    function testWithdrawalToZeroRecipient() public {
        (, bytes32 root) = _deposit(user);

        (,,, uint256 nullifierHash,,) = _getWithdrawInputs(root);

        uint256 relayerFee = 0;

        uint256 signalHash = PoseidonT6.hash(
            [
                uint256(uint160(address(0))),
                uint256(uint160(relayer)),
                relayerFee,
                block.chainid,
                uint256(uint160(address(obscura)))
            ]
        );

        uint256[2] memory _pA;
        uint256[2][2] memory _pB;
        uint256[2] memory _pC;

        vm.prank(relayer);
        vm.expectRevert(Obscura.Obscura__Invalid_Recipient.selector);

        obscura.withdraw(
            _pA, _pB, _pC, uint256(root), nullifierHash, payable(address(0)), payable(relayer), relayerFee, signalHash
        );
    }

    // -----------------------
    // SECURITY TESTS
    // -----------------------

    function testNullifierHashTracking() public {
        (, bytes32 root) = _deposit(user);

        (,,, uint256 nullifierHash,,) = _getWithdrawInputs(root);

        uint256 relayerFee = 0;

        uint256 signalHash = PoseidonT6.hash(
            [
                uint256(uint160(recipient)),
                uint256(uint160(relayer)),
                relayerFee,
                block.chainid,
                uint256(uint160(address(obscura)))
            ]
        );

        uint256[2] memory _pA;
        uint256[2][2] memory _pB;
        uint256[2] memory _pC;

        vm.prank(relayer);
        obscura.withdraw(
            _pA, _pB, _pC, uint256(root), nullifierHash, payable(recipient), payable(relayer), relayerFee, signalHash
        );

        assertTrue(obscura.nullifierHashes(nullifierHash));

        vm.prank(relayer);
        vm.expectRevert(Obscura.Obscura__NullifierHash_Already_Used.selector);

        obscura.withdraw(
            _pA, _pB, _pC, uint256(root), nullifierHash, payable(recipient), payable(relayer), relayerFee, signalHash
        );
    }

    function testFeeCollectorAccess() public {
        (, bytes32 root) = _deposit(user);

        (,,, uint256 nullifierHash,,) = _getWithdrawInputs(root);

        uint256 relayerFee = 0;

        uint256 signalHash = PoseidonT6.hash(
            [
                uint256(uint160(recipient)),
                uint256(uint160(relayer)),
                relayerFee,
                block.chainid,
                uint256(uint160(address(obscura)))
            ]
        );

        uint256 feeCollectorBefore = feeCollector.balance;

        uint256[2] memory _pA;
        uint256[2][2] memory _pB;
        uint256[2] memory _pC;

        vm.prank(relayer);
        obscura.withdraw(
            _pA, _pB, _pC, uint256(root), nullifierHash, payable(recipient), payable(relayer), relayerFee, signalHash
        );

        uint256 protocolFee = (1 ether * 20) / 10_000;

        assertEq(feeCollector.balance, feeCollectorBefore + protocolFee);
    }
}
