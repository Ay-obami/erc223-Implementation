// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Receiver interface defined by ERC-223.
interface IERC223Receiver {
    /// @dev Called by an ERC-223 token after balances have been updated.
    ///      A conforming receiver returns 0x8943ec02.
    function tokenReceived(
        address _from,
        uint256 _value,
        bytes calldata _data
    ) external returns (bytes4);
}
