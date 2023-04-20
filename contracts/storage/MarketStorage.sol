// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../utils/Admin.sol";

contract MarketStorage is Initializable, Admin {

    struct Sales {
        uint256 value;
        uint8 feeRate;
        address sender;
    }
    // トークン所有履歴
    mapping(address => uint256[]) internal assetLog;
    // 署名一覧
    mapping(bytes => bool) internal signatures;
    // 出品中アイテム: mapping(使用可能トークン => mapping(出品者address=>(tokenId => 価格)))
    mapping(address => mapping(address => mapping(uint256 => Sales))) internal itemOnSale;

    // 購入可能なERC721トークンのアドレス
    mapping(address => uint8) internal enable_tokens;
    // 購入に使用可能なERC20トークンのアドレス
    address internal currency_token;

    // 最低手数料 <ここで制御された手数料の内{purchaseFeeRate}%が購入代行者に支払われる>
    uint8 internal minimumTxFee;
    // 手数料の中で購入代行者に支払われる比率(%)
    uint8 internal purchaseFeeRate;
    // 販売規制解除 0:規制 1:解除
    uint8 internal salesRegulationCanceled;
    // 自由仲介規制解除 0:規制 1:解除
    uint8 internal proxyRegulationCanceled;
    // 一時停止
    bool internal paused;
}