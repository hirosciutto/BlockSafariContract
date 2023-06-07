// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "../storage/AnimalsStorage.sol";

contract Animals is ERC721EnumerableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, AnimalsStorage {
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

        // 最初のtokenIdを1に設定
        _tokenIdCounter.increment();
        idCodes.push(0);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return uri;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        _requireMinted(_tokenId);

        string memory baseURI = _baseURI();
        return string(abi.encodePacked(baseURI, StringsUpgradeable.toString(idCodes[_tokenId]), ".json"));
    }

    modifier mintable() {
        require(owner() == msg.sender || isTrusted(msg.sender), "caller is not the owner");
        _;
    }

    /**
     * 発行
     */
    function safeMint(
        address _to,
        uint256 _code
    ) public virtual mintable returns(uint256) {
        require(codes[_code] == 0, "code exists");

        // 現在のIDを取得
        uint256 tokenId = _tokenIdCounter.current();

        codes[_code] = tokenId;
        idCodes.push(_code);
        _safeMint(_to, tokenId);
        _tokenIdCounter.increment();

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

    function updateBaseURI(string memory _uri) public onlyOwner {
        uri = _uri;
    }

    function getBaseURI() public view returns(string memory) {
        return uri;
    }

    function codeId(uint256 _code) public virtual view returns(uint256) {
        return codes[_code];
    }

    function idCode(uint256 _tokenId) public virtual view returns(uint256) {
        return idCodes[_tokenId];
    }

    function codeOwnerOf(uint256 _code) public virtual view returns(address) {
        require(codes[_code] > 0 && ownerOf(codes[_code]) != address(0), "invalid code");
        return ownerOf(codes[_code]);
    }

    function _authorizeUpgrade(address) internal override virtual onlyOwner {}

}