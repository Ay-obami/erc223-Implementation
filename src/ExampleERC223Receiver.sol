// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC223Receiver} from "./IERC223Receiver.sol";

interface IERC223BalanceView {
    function balanceOf(address _owner) external view returns (uint256);
}

/// @notice Example contract that correctly handles ERC-223 deposits.
contract ExampleERC223Receiver is IERC223Receiver {
    error UnsupportedToken(address token);

    address public immutable acceptedToken;
    mapping(address => uint256) public deposits;

    address public lastFrom;
    uint256 public lastValue;
    bytes public lastData;
    uint256 public observedBalanceDuringHook;

    constructor(address acceptedToken_) {
        acceptedToken = acceptedToken_;
    }

    function tokenReceived(
        address _from,
        uint256 _value,
        bytes calldata _data
    ) external returns (bytes4) {
        // ERC-223 says msg.sender is the token contract. Filtering it prevents
        // arbitrary contracts or EOAs from fabricating a deposit record.
        if (msg.sender != acceptedToken) {
            revert UnsupportedToken(msg.sender);
        }

        // This value demonstrates that the token balance was updated before
        // the hook was invoked, as required by the EIP.
        observedBalanceDuringHook = IERC223BalanceView(msg.sender).balanceOf(
            address(this)
        );

        deposits[_from] += _value;
        lastFrom = _from;
        lastValue = _value;
        lastData = _data;

        return IERC223Receiver.tokenReceived.selector; // 0x8943ec02
    }
}
