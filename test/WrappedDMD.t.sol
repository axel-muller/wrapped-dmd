// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {WrappedDMD} from "src/WrappedDMD.sol";
import {MockReceiver} from "src/mocks/MockReceiver.sol";

contract WrappedDMDTest is Test {
    using SafeERC20 for WrappedDMD;

    WrappedDMD public wdmd;
    MockReceiver public receiver;

    address public alice;
    address public bob;

    uint256 public alicePk;
    uint256 public bobPk;

    function setUp() public {
        wdmd = new WrappedDMD();
        receiver = new MockReceiver();

        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(address(receiver), 100 ether);
    }

    function test_name() public view {
        assertEq(wdmd.name(), "Wrapped DMD");
    }

    function test_symbol() public view {
        assertEq(wdmd.symbol(), "WDMD");
    }

    function test_decimals() public view {
        assertEq(wdmd.decimals(), 18);
    }

    function test_initialTotalSupply() public view {
        assertEq(wdmd.totalSupply(), 0);
    }

    function test_deposit() public {
        uint256 amount = 1 ether;

        vm.prank(alice);
        wdmd.deposit{value: amount}();

        assertEq(wdmd.balanceOf(alice), amount);
        assertEq(wdmd.totalSupply(), amount);
        assertEq(address(wdmd).balance, amount);
    }

    function test_deposit_emitsTransfer() public {
        uint256 amount = 1 ether;

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), alice, amount);

        vm.prank(alice);
        wdmd.deposit{value: amount}();
    }

    function test_deposit_zero() public {
        vm.prank(alice);
        wdmd.deposit{value: 0}();

        assertEq(wdmd.balanceOf(alice), 0);
        assertEq(wdmd.totalSupply(), 0);
    }

    function test_deposit_multiple() public {
        vm.startPrank(alice);
        wdmd.deposit{value: 1 ether}();
        wdmd.deposit{value: 2 ether}();
        vm.stopPrank();

        assertEq(wdmd.balanceOf(alice), 3 ether);
        assertEq(wdmd.totalSupply(), 3 ether);
        assertEq(address(wdmd).balance, 3 ether);
    }

    function test_deposit_multipleUsers() public {
        uint256 aliceAmount = 3 ether;
        uint256 bobAmount = 5 ether;

        uint256 total = aliceAmount + bobAmount;

        vm.prank(alice);
        wdmd.deposit{value: aliceAmount}();

        vm.prank(bob);
        wdmd.deposit{value: bobAmount}();

        assertEq(wdmd.balanceOf(alice), aliceAmount);
        assertEq(wdmd.balanceOf(bob), bobAmount);
        assertEq(wdmd.totalSupply(), total);
        assertEq(address(wdmd).balance, total);
    }

    function test_depositByDirectTransfer() public {
        uint256 amount = 5 ether;

        vm.prank(alice);
        (bool success,) = address(wdmd).call{value: amount}("");
        assertTrue(success);

        assertEq(wdmd.balanceOf(alice), amount);
        assertEq(wdmd.totalSupply(), amount);
        assertEq(address(wdmd).balance, amount);
    }

    function test_depositByDirectTransfer_emitsTransfer() public {
        uint256 amount = 5 ether;

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), alice, amount);

        vm.prank(alice);
        (bool success,) = address(wdmd).call{value: amount}("");
        assertTrue(success);
    }

    function test_withdraw() public {
        uint256 depositAmount = 5 ether;
        uint256 withdrawAmount = 2 ether;

        uint256 aliceBalanceBefore = alice.balance;

        vm.startPrank(alice);
        wdmd.deposit{value: depositAmount}();
        wdmd.withdraw(withdrawAmount);
        vm.stopPrank();

        uint256 expectedAmount = depositAmount - withdrawAmount;

        assertEq(wdmd.balanceOf(alice), expectedAmount);
        assertEq(wdmd.totalSupply(), expectedAmount);
        assertEq(address(wdmd).balance, expectedAmount);
        assertEq(alice.balance, aliceBalanceBefore - expectedAmount);
    }

    function test_withdraw_all() public {
        uint256 amount = 10 ether;
        uint256 aliceBalanceBefore = alice.balance;

        vm.startPrank(alice);
        wdmd.deposit{value: amount}();

        assertEq(alice.balance, aliceBalanceBefore - amount);
        assertEq(wdmd.totalSupply(), amount);
        assertEq(wdmd.balanceOf(alice), amount);
        assertEq(address(wdmd).balance, amount);

        wdmd.withdraw(amount);
        vm.stopPrank();

        assertEq(alice.balance, aliceBalanceBefore);
        assertEq(wdmd.totalSupply(), 0);
        assertEq(wdmd.balanceOf(alice), 0);
        assertEq(address(wdmd).balance, 0);
    }

    function test_withdraw_emitsTransfer() public {
        uint256 amount = 5 ether;

        vm.prank(alice);
        wdmd.deposit{value: amount}();

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(alice, address(0), amount);

        vm.prank(alice);
        wdmd.withdraw(amount);
    }

    function test_withdraw_zero() public {
        uint256 amount = 1 ether;

        vm.prank(alice);
        wdmd.deposit{value: amount}();

        vm.prank(alice);
        wdmd.withdraw(0);

        assertEq(wdmd.balanceOf(alice), amount);
    }

    function test_withdraw_revertsInsufficientBalance() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 2 ether;

        vm.prank(alice);
        wdmd.deposit{value: depositAmount}();

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, depositAmount, withdrawAmount)
        );

        vm.prank(alice);
        wdmd.withdraw(withdrawAmount);
    }

    function test_withdraw_revertsWhenNoDeposit() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1 ether));

        vm.prank(alice);
        wdmd.withdraw(1 ether);
    }

    function test_withdraw_revertsDMDTransferFailed() public {
        uint256 amount = 5 ether;

        vm.prank(address(receiver));
        wdmd.deposit{value: amount}();
        assertEq(wdmd.balanceOf(address(receiver)), amount);

        receiver.toggleReceive(false);

        vm.prank(address(receiver));
        vm.expectRevert(WrappedDMD.DMDTransferFailed.selector);
        wdmd.withdraw(amount);
    }

    function test_withdraw_succeedsWhenRecipientAccepts() public {
        uint256 amount = 5 ether;
        uint256 balanceBefore = address(receiver).balance;

        receiver.toggleReceive(true);

        vm.startPrank(address(receiver));
        wdmd.deposit{value: amount}();
        assertEq(address(receiver).balance, balanceBefore - amount);

        wdmd.withdraw(amount);

        assertEq(wdmd.balanceOf(address(receiver)), 0);
        assertEq(address(receiver).balance, balanceBefore);

        vm.stopPrank();
    }

    function test_depositWithdraw_roundTrip() public {
        uint256 balanceBefore = alice.balance;
        uint256 amount = 5 ether;

        vm.startPrank(alice);
        wdmd.deposit{value: amount}();
        wdmd.withdraw(amount);
        vm.stopPrank();

        assertEq(alice.balance, balanceBefore);
        assertEq(wdmd.balanceOf(alice), 0);
        assertEq(wdmd.totalSupply(), 0);
        assertEq(address(wdmd).balance, 0);
    }

    function test_transfer() public {
        uint256 depositAmount = 10 ether;
        uint256 transferAmount = 4 ether;

        vm.prank(alice);
        wdmd.deposit{value: depositAmount}();

        vm.prank(alice);
        bool success = wdmd.transfer(bob, transferAmount);
        assertTrue(success);

        assertEq(wdmd.balanceOf(alice), depositAmount - transferAmount);
        assertEq(wdmd.balanceOf(bob), transferAmount);
        assertEq(wdmd.totalSupply(), depositAmount);
    }

    function test_transfer_emitsEvent() public {
        uint256 amount = 2 ether;

        vm.prank(alice);
        wdmd.deposit{value: amount}();

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(alice, bob, amount);

        vm.prank(alice);
        wdmd.safeTransfer(bob, amount);
    }

    function test_transfer_revertsInsufficientBalance() public {
        uint256 depositAmount = 1 ether;
        uint256 transferAmount = depositAmount * 2;

        vm.prank(alice);
        wdmd.deposit{value: depositAmount}();

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, depositAmount, transferAmount)
        );

        vm.prank(alice);
        bool ok = wdmd.transfer(bob, transferAmount);
        assertFalse(ok);
    }

    function test_approve() public {
        uint256 amount = 5 ether;

        vm.prank(alice);
        bool success = wdmd.approve(bob, amount);
        assertTrue(success);

        assertEq(wdmd.allowance(alice, bob), amount);
    }

    function test_approve_emitsEvent() public {
        uint256 amount = 5 ether;

        vm.expectEmit(true, true, true, true);
        emit IERC20.Approval(alice, bob, amount);

        vm.prank(alice);
        wdmd.approve(bob, amount);
    }

    function test_transferFrom() public {
        vm.prank(alice);
        wdmd.deposit{value: 10 ether}();

        vm.prank(alice);
        wdmd.approve(bob, 6 ether);

        vm.prank(bob);
        bool success = wdmd.transferFrom(alice, bob, 4 ether);
        assertTrue(success);

        assertEq(wdmd.balanceOf(alice), 6 ether);
        assertEq(wdmd.balanceOf(bob), 4 ether);
        assertEq(wdmd.allowance(alice, bob), 2 ether);
    }

    function test_transferFrom_revertsInsufficientAllowance() public {
        uint256 approveAmount = 1 ether;
        uint256 transferAmount = 5 ether;

        vm.prank(alice);
        wdmd.deposit{value: transferAmount * 2}();

        vm.prank(alice);
        wdmd.approve(bob, approveAmount);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, approveAmount, transferAmount)
        );

        vm.prank(bob);
        bool ok = wdmd.transferFrom(alice, bob, transferAmount);
        assertFalse(ok);
    }

    function test_transferFrom_infiniteAllowance() public {
        uint256 approveAmount = type(uint256).max;
        uint256 transferAmount = 3 ether;

        vm.prank(alice);
        wdmd.deposit{value: 10 ether}();

        vm.prank(alice);
        wdmd.approve(bob, approveAmount);

        vm.prank(bob);
        wdmd.safeTransferFrom(alice, bob, transferAmount);

        assertEq(wdmd.allowance(alice, bob), approveAmount);
        assertEq(wdmd.balanceOf(bob), transferAmount);
    }

    function test_permit() public {
        uint256 value = 5 ether;
        uint256 deadline = block.timestamp + 1 minutes;
        uint256 nonce = wdmd.nonces(alice);

        bytes32 permitHash = _getPermitHash(alice, bob, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, permitHash);

        wdmd.permit(alice, bob, value, deadline, v, r, s);

        assertEq(wdmd.allowance(alice, bob), value);
        assertEq(wdmd.nonces(alice), 1);
    }

    function test_permit_emitsApproval() public {
        uint256 value = 5 ether;
        uint256 deadline = block.timestamp + 1 minutes;
        uint256 nonce = wdmd.nonces(alice);

        bytes32 permitHash = _getPermitHash(alice, bob, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, permitHash);

        vm.expectEmit(true, true, true, true);
        emit IERC20.Approval(alice, bob, value);

        wdmd.permit(alice, bob, value, deadline, v, r, s);
    }

    function test_permit_revertsExpiredDeadline() public {
        uint256 value = 5 ether;
        uint256 deadline = block.timestamp - 1;
        uint256 nonce = wdmd.nonces(alice);

        bytes32 permitHash = _getPermitHash(alice, bob, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, permitHash);

        vm.expectRevert(abi.encodeWithSelector(ERC20Permit.ERC2612ExpiredSignature.selector, deadline));
        wdmd.permit(alice, bob, value, deadline, v, r, s);
    }

    function test_permit_revertsInvalidSigner() public {
        uint256 value = 5 ether;
        uint256 deadline = block.timestamp + 1 minutes;
        uint256 nonce = wdmd.nonces(alice);

        bytes32 permitHash = _getPermitHash(alice, bob, value, nonce, deadline);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, permitHash);

        vm.expectRevert(abi.encodeWithSelector(ERC20Permit.ERC2612InvalidSigner.selector, bob, alice));
        wdmd.permit(alice, bob, value, deadline, v, r, s);
    }

    function test_permit_revertsReplayedNonce() public {
        uint256 value = 5 ether;
        uint256 deadline = block.timestamp + 1 minutes;
        uint256 nonce = wdmd.nonces(alice);

        bytes32 permitHash = _getPermitHash(alice, bob, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, permitHash);

        wdmd.permit(alice, bob, value, deadline, v, r, s);

        vm.expectPartialRevert(ERC20Permit.ERC2612InvalidSigner.selector);
        wdmd.permit(alice, bob, value, deadline, v, r, s);
    }

    function test_DOMAIN_SEPARATOR() public view {
        bytes32 domainSeparator = wdmd.DOMAIN_SEPARATOR();
        assertTrue(domainSeparator != bytes32(0));
    }

    function test_nonces_initialZero() public view {
        assertEq(wdmd.nonces(alice), 0);
        assertEq(wdmd.nonces(bob), 0);
    }

    function test_depositTransferWithdraw() public {
        vm.prank(alice);
        wdmd.deposit{value: 10 ether}();

        vm.prank(alice);
        wdmd.safeTransfer(bob, 4 ether);

        uint256 bobBalanceBefore = bob.balance;

        vm.prank(bob);
        wdmd.withdraw(4 ether);

        assertEq(wdmd.balanceOf(alice), 6 ether);
        assertEq(wdmd.balanceOf(bob), 0);
        assertEq(bob.balance, bobBalanceBefore + 4 ether);
        assertEq(address(wdmd).balance, 6 ether);
    }

    function test_permitAndTransferFrom() public {
        vm.prank(alice);
        wdmd.deposit{value: 10 ether}();

        uint256 value = 6 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = wdmd.nonces(alice);

        bytes32 permitHash = _getPermitHash(alice, bob, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, permitHash);

        vm.prank(bob);
        wdmd.permit(alice, bob, value, deadline, v, r, s);

        vm.prank(bob);
        wdmd.safeTransferFrom(alice, bob, 6 ether);

        assertEq(wdmd.balanceOf(alice), 4 ether);
        assertEq(wdmd.balanceOf(bob), 6 ether);
        assertEq(wdmd.allowance(alice, bob), 0);
    }

    function testFuzz_deposit(uint96 amount) public {
        vm.deal(alice, amount);

        vm.prank(alice);
        wdmd.deposit{value: amount}();

        assertEq(wdmd.balanceOf(alice), amount);
        assertEq(wdmd.totalSupply(), amount);
        assertEq(address(wdmd).balance, amount);
    }

    function testFuzz_depositByDirectTransfer(uint96 amount) public {
        vm.deal(alice, amount);

        vm.prank(alice);
        (bool success,) = address(wdmd).call{value: amount}("");
        assertTrue(success);

        assertEq(wdmd.balanceOf(alice), amount);
        assertEq(wdmd.totalSupply(), amount);
        assertEq(address(wdmd).balance, amount);
    }

    function testFuzz_withdraw(uint96 depositAmount, uint96 withdrawAmount) public {
        vm.assume(withdrawAmount <= depositAmount);
        vm.deal(alice, depositAmount);

        vm.startPrank(alice);
        wdmd.deposit{value: depositAmount}();
        wdmd.withdraw(withdrawAmount);
        vm.stopPrank();

        uint256 remaining = uint256(depositAmount) - uint256(withdrawAmount);
        assertEq(wdmd.balanceOf(alice), remaining);
        assertEq(wdmd.totalSupply(), remaining);
        assertEq(address(wdmd).balance, remaining);
    }

    function _getPermitHash(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline)
        internal
        view
        returns (bytes32)
    {
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash = keccak256(abi.encode(permitTypehash, owner, spender, value, nonce, deadline));

        return keccak256(abi.encodePacked("\x19\x01", wdmd.DOMAIN_SEPARATOR(), structHash));
    }
}
