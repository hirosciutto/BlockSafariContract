// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ProxyStorage is Initializable {

    // 購入に使用可能なERC20トークンのアドレス
    address internal currency_token;

    /**
     * マスター権限
     * admin/agentの管理
     */
    address internal _owner;
    /**
     * 管理権限
     * 0 => admin: ゲームの管理アカウント
     * 1 => agent: APIからトークンのmint可能
     */
    mapping(uint256 => mapping(address => bool)) internal _admin;

    // 一時停止
    bool internal paused;

    /**
     * ERC721変数
     */
    // Token name
    string internal _name;
    // Token symbol
    string internal _symbol;
    // Token Image URI path
    string internal _uri;
    // Mapping from token ID to owner address
    mapping(uint256 => address) internal _owners;
    // Mapping owner address to token count
    mapping(address => uint256) internal _balances;
    // Mapping from token ID to approved address
    mapping(uint256 => address) internal _tokenApprovals;
    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) internal _operatorApprovals;


    /**
     * sale(トークンによる購入)用変数
     */
    // トークン所有履歴
    mapping(address => uint256[]) internal assetLog;
    // 署名一覧
    mapping(bytes => bool) internal signatures;
    // 出品中アイテム: mapping(使用可能トークン => mapping(出品者address=>(tokenId => 価格)))
    mapping(address => mapping(address => mapping(uint256 => Sales))) internal itemOnSale;
    struct Sales {
        uint256 value;
        uint256 feeRate;
        address sender;
    }
    // 販売規制解除 0:規制 1:解除
    uint8 salesRegulationCanceled;
    // 自由仲介規制解除 0:規制 1:解除
    uint8 agentListRegulationCanceled;
}