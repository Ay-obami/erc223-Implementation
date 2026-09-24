// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Deliberately does NOT implement tokenReceived.
/// @dev ERC-223 transfers to this contract must revert.
contract NonERC223Receiver {
    uint256 public marker = 223;
}
