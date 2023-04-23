// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISafariToken {
    function externalTransferFrom(address _from, address _to, uint256 _value) external returns(bool);
}