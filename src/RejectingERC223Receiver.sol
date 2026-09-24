// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC223Receiver} from "./IERC223Receiver.sol";

/// @notice Implements the ERC-223 hook but deliberately rejects every transfer.
contract RejectingERC223Receiver is IERC223Receiver {
    error TransferRejected();

    function tokenReceived(
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        revert TransferRejected();
    }
}
