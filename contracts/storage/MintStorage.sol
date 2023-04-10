// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../utils/Admin.sol";

contract MintStorage is Initializable, Admin {

    // 署名一覧
    mapping(bytes => bool) internal signatures;

    // 最低手数料 <ここで制御された手数料の内{purchaseFeeRate}%が購入代行者に支払われる>
    uint8 minimumTxFee;

    // 購入可能なERC721トークンのアドレス
    mapping(address => bool) internal enable_tokens;
    // 購入に使用可能なERC20トークンのアドレス
    address internal currency_token;

    // 自由仲介規制解除 0:規制 1:解除
    uint8 proxyRegulationCanceled;

    // 一時停止
    bool internal paused;

    // 交配のパラメータ
    struct CrossbreedSeed {
        bytes signature;
        uint256 parentTokenId;
        uint256 partnerTokenId;
        uint256 fee;
        uint256 nonce;
        uint256 newBorn;
    }

    mapping(uint256 => uint256[]) internal family;

    // 交配可能期間制御 tokenId => timestamp
    mapping(uint256 => uint256) crossbreedLock;
    uint256 crossbreedLockDays;
}