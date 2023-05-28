// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../utils/Admin.sol";

contract MintStorage is Initializable, Admin {

    // 署名一覧
    mapping(bytes => bool) internal signatures;

    // 最低手数料
    uint256 internal minimumTxFee;

    // mint可能なERC721トークンのアドレス
    mapping(address => bool) internal enable_tokens;
    // 購入に使用可能なERC20トークンのアドレス
    address internal coin_token;
    // 紙幣
    mapping(uint256 => address) internal note_token;

    // 自由仲介規制解除 0:規制 1:解除
    uint8 internal proxyRegulationCanceled;

    // 一時停止
    bool internal paused;
}