// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../NftStorage.sol";

abstract contract ERC721Wrapper is UUPSUpgradeable, ERC721Upgradeable, OwnableUpgradeable, NftStorage {

    constructor() {}

    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) public initializer {
        // name,symbol,データのURL設定
        __ERC721_init(_name, _symbol);
        uri = _uri;
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

    /**
     * 発行
     */
    function safeMint(
        address to,
        uint256 tokenId
    ) public virtual onlyAdmin(0) {
        _safeMint(to, tokenId);
    }


    modifier onlyTrusted() {
        require(trusted[msg.sender] == true);
        _;
    }

    /**
     * ホワイトリスト制御
     */
    function trust(address _tokenAddress, bool _status) onlyOwner public {
        require(!trusted[_tokenAddress], "invalid operation");
        trusted[_tokenAddress] = _status;
    }

    /**
     * 外部からの信頼できるtransferFrom
     */
    function externalTransferFrom(address _from, address _to, uint256 _tokenId) onlyTrusted public {
        require(_from == ERC721Upgradeable.ownerOf(_tokenId), "invalid owner");
        _transfer(_from, _to, _tokenId);
    }

    /**
    * 外部からのmint要請
    */
    function externalMint(
        address _minter,
        uint248 _dnaCode
    )
        external
        virtual
        onlyTrusted
    {
        // 70桁以下の数値であること
        require(_dnaCode <= 9999999999999999999999999999999999999999999999999999999999999999999999, "DNA digits limit");

        uint256 tokenId = createTokenId(uint256(_dnaCode) * 10000000);

        _safeMint(_minter, tokenId);
    }

    /**
    * 外部からの交配要請
    * 後輩の整合性はサーバーサイドの計算を絶対的に信頼する
    */
    function externalCrossbreed(
        address _minter,
        uint256 _parentTokenId1,
        uint256 _parentTokenId2,
        uint248 _dnaCode
    )
        external
        virtual
        onlyTrusted
    {
        // 70桁以下の数値であること
        require(_dnaCode <= 9999999999999999999999999999999999999999999999999999999999999999999999, "DNA digits limit");
        uint256 tokenId = createTokenId(uint256(_dnaCode) * 10000000);
        // mint
        _safeMint(_minter, tokenId);

        // 父母の登録
        family[tokenId][0] = _parentTokenId1;
        family[tokenId][1] = _parentTokenId2;
    }

    function getParents(uint256 tokenId) public view returns(uint256, uint256){
        return (family[tokenId][0], family[tokenId][1]);
    }

    function createTokenId(uint256 code) private returns(uint256) {
        require(tokenIdBox[code] < 9999999, "same DNAs limit"); // 7桁を超えていないこと
        uint256 tokenId = code + uint256(tokenIdBox[code]);
        tokenIdBox[code]++;
        return tokenId;
    }

}