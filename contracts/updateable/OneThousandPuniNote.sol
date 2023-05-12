// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../storage/PuniNoteStorage.sol";

contract OneThousandPuniNote is ERC721Upgradeable, OwnableUpgradeable, UUPSUpgradeable, PuniNoteStorage {
    // カウンターstructをuse
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeMathUpgradeable for uint256;

    constructor() {}

    function initialize(address _coinTokenAddress) public initializer {
        // name,symbol,データのURL設定
        __ERC721_init("1000 PUNI NOTE", "PUNIx1K");
        __Ownable_init();
        admin[0][msg.sender] = true;
        unit = 1000;
        coin_token = _coinTokenAddress;
        safeMint(msg.sender);// test
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory svg = getSVG(tokenId);
        bytes memory json = abi.encodePacked(
            '{"name": "1000 PUNI NOTE #',
            StringsUpgradeable.toString(tokenId),
            '", "description": "One Thousand PUNI NOTE is a full on-chain text NFT.", "image": "data:image/svg+xml;base64,',
            Base64Upgradeable.encode(bytes(svg)),
            '"}'
        );
        return string(abi.encodePacked("data:application/json;base64,", Base64Upgradeable.encode(json)));
    }

    function getSVG(uint256 tokenId) public virtual view returns(string memory) {
        string memory imageData = '';

        for (uint256 i = 0; i < totalChunks; i++) {
            imageData = string.concat(imageData, imageChunks[i]);
        }

        return string(
            abi.encodePacked(
                '<svg version="1.1" id="Image" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 286"><image id="image0" width="600" height="286" x="0" y="0" href="',
                imageData,
                '" /><foreignObject xmlns="http://www.w3.org/2000/svg" width="600" height="160" x="63" y="130"><html xmlns="http://www.w3.org/1999/xhtml"><b style="font-size:20px;color:#a86c0a;">',
                padNumberWithZeros(tokenId),
                '</b></html></foreignObject></svg>'
            )
        );
    }

    function padNumberWithZeros(uint256 number) public pure returns (string memory) {
        string memory numberString = StringsUpgradeable.toString(number);
        uint256 length = bytes(numberString).length;

        // 桁数が8未満の場合、不足する桁数分を0で埋める
        if (length < 8) {
            string memory zeros = new string(8 - length);
            bytes memory zerosBytes = bytes(zeros);
            for (uint256 i = 0; i < zerosBytes.length; i++) {
                zerosBytes[i] = "0";
            }
            return string(abi.encodePacked(zerosBytes, numberString));
        }

        return numberString;
    }

    function setImageChunk(uint256 chunkIndex, string memory data) public onlyOwner {
        imageChunks[chunkIndex] = data;
        if (chunkIndex + 1 > totalChunks) {
            totalChunks = chunkIndex + 1;
        }
    }

    /**
     * 発行は通貨の預入によってのみ行われる
     */
    function deposit(
        uint256 _amount
    ) public virtual payable {
        // 数値チェック
        require(_tokenIdCounter.current() <= 50000000 * (10**18), "note mint limit");
        (, uint256 deposits) = SafeMathUpgradeable.tryMul(_amount, unit);
        require(deposits > 0, "invalid amount");
        // 実行者が両替できるほどのコインを持っているか？
        require(IERC20Upgradeable(coin_token).balanceOf(msg.sender) >= deposits, "lack of funds");

        // 関数の実行前に、残っているGASの量を取得する
        uint256 gasStart = gasleft();

        // 通貨の預入
        (bool success, ) = coin_token.call(abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", msg.sender, address(this), deposits));
        require(success, "External function execution failed deposit");

        // 保管紙幣の不足枚数 = 要求紙幣 - 保管紙幣
        (, uint256 mintCnt) = SafeMathUpgradeable.trySub(_amount, balanceOf(address(this)));
        // 保管からの払出枚数 = 要求紙幣 - 保管紙幣の不足枚数
        (, uint256 changeCnt) = SafeMathUpgradeable.trySub(_amount, mintCnt);
        if (changeCnt > 0) {
            // 保管紙幣の払出
            uint idx = custody_minimum_idx;
            custody_minimum_idx = custody_minimum_idx + changeCnt;
            for (uint i = idx; i < custody_minimum_idx + changeCnt; i++) {
                _transfer(address(this), msg.sender, custody[i]);
            }
        }
        if (mintCnt > 0) {
            // 発行が必要
            for (uint i = 0; i < mintCnt; i++) {
                safeMint(msg.sender);
            }
        }

        // 関数が使用したGASの量を計算する
        uint256 gasUsed = gasStart.sub(gasleft());

        // 未使用のETHを返還する
        uint256 refundAmount = msg.value.sub(gasUsed.mul(tx.gasprice));
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }
    }

    /**
     * 紙幣を返却してコインを払い出す
     */
    function withdraw(
        uint[] memory tokenIds
    ) public virtual payable {
        // 保管を確認
        require(ERC20Upgradeable(coin_token).balanceOf(address(this)) > tokenIds.length.mul(unit), "lack of change");
        // 関数の実行前に、残っているGASの量を取得する
        uint256 gasStart = gasleft();
        for (uint i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == msg.sender, "you are not owner"); // 所有権確認
            _transfer(msg.sender, address(this), tokenIds[i]); // 紙幣預入
            custody.push(tokenIds[i]); // 保管リストに追加
            _custodyCounter.increment();
        }

        // 払い出し
        (bool success, ) = coin_token.call(abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", address(this), msg.sender, tokenIds.length.mul(unit)));
        require(success, "External function execution failed payout");

        // 関数が使用したGASの量を計算する
        uint256 gasUsed = gasStart.sub(gasleft());

        // 未使用のETHを返還する
        uint256 refundAmount = msg.value.sub(gasUsed.mul(tx.gasprice));
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }
    }

    function safeMint(address _to) internal virtual {
        // 現在のIDを取得
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(_to, tokenId);

        // インクリメント
        _tokenIdCounter.increment();
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


    /**
     * for opensea
     */
    function isApprovedForAll(
        address _owner,
        address _operator
    ) public override virtual view returns (bool isOperator) {
      // if OpenSea's ERC721 Proxy Address is detected, auto-return true
        if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)) {
            return true;
        }

        // otherwise, use the default ERC721.isApprovedForAll()
        return ERC721Upgradeable.isApprovedForAll(_owner, _operator);
    }

    function _authorizeUpgrade(address) internal override virtual onlyOwner {}

}