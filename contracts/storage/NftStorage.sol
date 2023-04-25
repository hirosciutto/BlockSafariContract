// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "../utils/Admin.sol";

contract NftStorage is Initializable,Admin {

    // カウンターstructをuse
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // 状態変数 _tokenIdConter で、ライブラリを使用できるようにする
    CountersUpgradeable.Counter internal _tokenIdCounter;

    mapping(address => bool) internal trusted;

    string internal uri;

    mapping(uint256 => uint256) codes;
}