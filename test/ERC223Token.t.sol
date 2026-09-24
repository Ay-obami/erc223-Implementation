// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ERC223Token} from "../src/ERC223Token.sol";
import {ExampleERC223Receiver} from "../src/ExampleERC223Receiver.sol";
import {NonERC223Receiver} from "../src/NonERC223Receiver.sol";
import {RejectingERC223Receiver} from "../src/RejectingERC223Receiver.sol";
import {IERC223Receiver} from "../src/IERC223Receiver.sol";

contract ERC223TokenTest is Test {
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 _value,
        bytes _data
    );

    ERC223Token internal token;
    ExampleERC223Receiver internal receiver;
    NonERC223Receiver internal nonReceiver;
    RejectingERC223Receiver internal rejectingReceiver;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant INITIAL_SUPPLY = 1_000 ether;

    function setUp() public {
        token = new ERC223Token("Course ERC223", "C223", 18, INITIAL_SUPPLY);
        receiver = new ExampleERC223Receiver(address(token));
        nonReceiver = new NonERC223Receiver();
        rejectingReceiver = new RejectingERC223Receiver();

        token.transfer(alice, 300 ether);
    }

    function testMetadataAndInitialSupply() public view {
        assertEq(token.name(), "Course ERC223");
        assertEq(token.symbol(), "C223");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function testTransferToEOAWorksNormally() public {
        vm.prank(alice);
        bool ok = token.transfer(bob, 40 ether);

        assertTrue(ok);
        assertEq(token.balanceOf(alice), 260 ether);
        assertEq(token.balanceOf(bob), 40 ether);
    }

    function testTransferEmitsERC223EventWithData() public {
        bytes memory data = hex"1234";

        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(alice, bob, 5 ether, data);

        vm.prank(alice);
        token.transfer(bob, 5 ether, data);
    }

    function testTransferToCompatibleContractCallsHookWithData() public {
        bytes memory data = abi.encode("invoice-42");

        vm.prank(alice);
        bool ok = token.transfer(address(receiver), 25 ether, data);

        assertTrue(ok);
        assertEq(token.balanceOf(alice), 275 ether);
        assertEq(token.balanceOf(address(receiver)), 25 ether);
        assertEq(receiver.deposits(alice), 25 ether);
        assertEq(receiver.lastFrom(), alice);
        assertEq(receiver.lastValue(), 25 ether);
        assertEq(receiver.lastData(), data);
    }

    function testHookRunsAfterBalanceUpdate() public {
        vm.prank(alice);
        token.transfer(address(receiver), 12 ether, hex"CAFE");

        assertEq(receiver.observedBalanceDuringHook(), 12 ether);
        assertEq(token.balanceOf(address(receiver)), 12 ether);
    }

    function testNoDataOverloadUsesEmptyData() public {
        vm.prank(alice);
        token.transfer(address(receiver), 7 ether);

        assertEq(receiver.lastData().length, 0);
    }

    // Failure case 1: contract recipient has no tokenReceived hook.
    function testRevertWhenContractDoesNotImplementHook() public {
        uint256 aliceBefore = token.balanceOf(alice);

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(address(nonReceiver), 10 ether);

        assertEq(token.balanceOf(alice), aliceBefore);
        assertEq(token.balanceOf(address(nonReceiver)), 0);
    }

    // Failure case 2: receiver implements the hook but explicitly rejects.
    function testRevertWhenReceiverRejectsTransfer() public {
        uint256 aliceBefore = token.balanceOf(alice);

        vm.prank(alice);
        vm.expectRevert(RejectingERC223Receiver.TransferRejected.selector);
        token.transfer(address(rejectingReceiver), 10 ether, hex"01");

        assertEq(token.balanceOf(alice), aliceBefore);
        assertEq(token.balanceOf(address(rejectingReceiver)), 0);
    }

    // Failure case 3: sender attempts to transfer more than its balance.
    function testRevertOnInsufficientBalance() public {
        uint256 aliceBalance = token.balanceOf(alice);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC223Token.InsufficientBalance.selector,
                alice,
                aliceBalance,
                aliceBalance + 1
            )
        );
        token.transfer(bob, aliceBalance + 1);

        assertEq(token.balanceOf(alice), aliceBalance);
        assertEq(token.balanceOf(bob), 0);
    }

    function testReceiverRejectsDirectFakeHookCall() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExampleERC223Receiver.UnsupportedToken.selector,
                alice
            )
        );
        receiver.tokenReceived(alice, 1 ether, "");
    }

    function testReceiverReturnsPublishedMagicValue() public pure {
        assertEq(
            bytes32(IERC223Receiver.tokenReceived.selector),
            bytes32(bytes4(0x8943ec02))
        );
    }

    function testFuzzTransferToEOA(uint96 amount) public {
        uint256 bounded = bound(uint256(amount), 0, 300 ether);

        vm.prank(alice);
        token.transfer(bob, bounded);

        assertEq(token.balanceOf(bob), bounded);
        assertEq(token.balanceOf(alice), 300 ether - bounded);
    }
}
