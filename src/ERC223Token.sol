// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC223Receiver} from "./IERC223Receiver.sol";

contract ERC223Token {
    error InsufficientBalance(address sender, uint256 balance, uint256 required);

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;

    event Transfer(address indexed _from, address indexed _to, uint256 _value, bytes _data);

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 initialSupply_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _totalSupply = initialSupply_;
        _balances[msg.sender] = initialSupply_;

        emit Transfer(address(0), msg.sender, initialSupply_, "");
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return _balances[_owner];
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        return _transfer(msg.sender, _to, _value, "");
    }

    function transfer(address _to, uint256 _value, bytes calldata _data) external returns (bool) {
        return _transfer(msg.sender, _to, _value, _data);
    }

    function _transfer(address _from, address _to, uint256 _value, bytes memory _data) internal returns (bool) {
        uint256 senderBalance = _balances[_from];
        if (senderBalance < _value) {
            revert InsufficientBalance(_from, senderBalance, _value);
        }

        // ERC-223 requires the receiver callback to happen only after the
        // token's own state transition. If the callback reverts, EVM atomicity
        // rolls these balance writes back as well.

        _balances[_from] -= _value;

        _balances[_to] += _value;

        // EIP-223 distinguishes EOAs from contracts by code size. A contract
        // recipient must expose tokenReceived or this external call reverts.
        if (_to.code.length > 0) {
            IERC223Receiver(_to).tokenReceived(_from, _value, _data);
        }

        emit Transfer(_from, _to, _value, _data);
        return true;
    }
}
