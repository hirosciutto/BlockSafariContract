// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../storage/AnimalsStorage.sol";

contract Animals is ERC721Upgradeable, OwnableUpgradeable, UUPSUpgradeable, AnimalsStorage {
    // カウンターstructをuse
    using CountersUpgradeable for CountersUpgradeable.Counter;

    constructor() {}

    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) public initializer {
        // name,symbol,データのURL設定
        __ERC721_init(_name, _symbol);
        __Ownable_init();
        // __UUPSUpgradeable_init();
        uri = _uri;
        admin[0][msg.sender] = true;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return uri;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId, ".json")) : "";
    }

    modifier mintable() {
        require(admin[0][msg.sender] == true || owner() == msg.sender || isTrusted(msg.sender), "caller is not the owner");
        _;
    }

    /**
     * 発行
     */
    function safeMint(
        address _to,
        uint256 _code
    ) public virtual mintable returns(uint256) {
        // インクリメント
        _tokenIdCounter.increment();

        // 現在のIDを取得
        uint256 tokenId = _tokenIdCounter.current();

        codes[_code] = tokenId;
        _safeMint(_to, tokenId);

        return tokenId;
    }


    modifier onlyTrusted() {
        require(trusted[msg.sender] == true);
        _;
    }

    /**
     * ホワイトリスト制御
     */
    function trust(address _contractAddress, bool _status) onlyOwner public virtual {
        require(!trusted[_contractAddress], "invalid operation");
        trusted[_contractAddress] = _status;
    }

    /**
     * ホワイトリスト確認
     */
    function isTrusted(address _contractAddress) public view virtual returns(bool) {
        return trusted[_contractAddress];
    }

    /**
     * 外部からの信頼できるtransferFrom
     */
    function externalTransferFrom(address _from, address _to, uint256 _tokenId) onlyTrusted public virtual {
        require(_from == ERC721Upgradeable.ownerOf(_tokenId), "invalid owner");
        _transfer(_from, _to, _tokenId);
    }

    function tokenExists(uint256 _tokenId) public virtual view returns(bool) {
        return _exists(_tokenId);
    }

    function updateBaseURI(string memory _uri) public virtual {
        uri = _uri;
    }

    function codeId(uint256 _code) public virtual view returns(uint256) {
        return codes[_code];
    }

    function codeOwnerOf(uint256 _code) public virtual view returns(address) {
        require(codes[_code] > 0 && ownerOf(codes[_code]) != address(0), "invalid code");
        return ownerOf(codes[_code]);
    }

    function _authorizeUpgrade(address) internal override virtual onlyOwner {}

}