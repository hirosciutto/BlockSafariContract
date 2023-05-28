// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract PuniNoteStorage is Initializable {

    // カウンターstructをuse
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // 状態変数 _tokenIdConter,_custodyCounter で、ライブラリを使用できるようにする
    CountersUpgradeable.Counter internal _tokenIdCounter;
    CountersUpgradeable.Counter internal _custodyCounter;

    mapping(address => bool) internal trusted;

    mapping(uint256 => string) internal imageChunks;
    uint256 internal totalChunks;

    address internal coin_token;

    uint256 internal unit;

    uint256[] internal custody;
    uint256 internal custody_minimum_idx;
}