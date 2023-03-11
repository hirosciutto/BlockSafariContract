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
        uint256 _tokenId
    )
        external
        virtual
        onlyTrusted
    {
        require(address(0) == ERC721Upgradeable.ownerOf(_tokenId), "invalid owner");
        _safeMint(_minter, _tokenId);
    }

}