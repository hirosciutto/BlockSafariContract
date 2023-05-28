// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../storage/PuniNoteStorage.sol";

contract OneMillionPuniNote is ERC721EnumerableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, PuniNoteStorage {
    // カウンターstructをuse
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeMathUpgradeable for uint256;

    event SetCurrencyToken(address _tokenAddress);
    event Deposit(uint256 _value);
    event Withdraw(uint256 _value);

    constructor() {}

    function initialize(address _coinTokenAddress) public initializer {
        // name,symbol,データのURL設定
        __ERC721_init("One Million PUNI NOTE", "MPUNI");
        __Ownable_init();
        unit = 1000000;
        setCurrencyToken(_coinTokenAddress);
        _tokenIdCounter.increment();
    }

    function setCurrencyToken(address _tokenAddress) public virtual onlyOwner {
        require(_tokenAddress != address(0), "invalid tokenAddress");
        coin_token = _tokenAddress;
        emit SetCurrencyToken(_tokenAddress);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory svg = getSVG(tokenId);
        bytes memory json = abi.encodePacked(
            '{"name": "One Million PUNI NOTE #',
            StringsUpgradeable.toString(tokenId),
            '", "description": "One Million PUNI NOTE is a full on-chain text NFT.", "image": "data:image/svg+xml;base64,',
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
        totalChunks = chunkIndex + 1;
    }

    /**
     * 発行は通貨の預入によってのみ行われる
     */
    function deposit(
        uint256 _noteAmountRequested
    ) public virtual payable {
        // 数値チェック
        (, uint256 depositValue) = SafeMathUpgradeable.tryMul(_noteAmountRequested, unit * (10**18));
        require(depositValue > 0, "invalid amount");
        // 実行者が両替できるほどのコインを持っているか？
        require(IERC20Upgradeable(coin_token).balanceOf(msg.sender) >= depositValue, "lack of funds");

        // 関数の実行前に、残っているGASの量を取得する
        uint256 gasStart = gasleft();

        // 通貨の預入
        (bool success, ) = coin_token.call(abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", msg.sender, address(this), depositValue));
        require(success, "External function execution failed deposit");

        // 保管紙幣の不足枚数 = 要求紙幣 - 保管紙幣
        (, uint256 mintCnt) = SafeMathUpgradeable.trySub(_noteAmountRequested, balanceOf(address(this)));
        // 保管からの払出枚数 = 要求紙幣 - 保管紙幣の不足枚数
        (, uint256 changeCnt) = SafeMathUpgradeable.trySub(_noteAmountRequested, mintCnt);
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
        emit Deposit(depositValue);
    }

    /**
     * 紙幣を返却してコインを払い出す
     */
    function withdraw(
        uint256[] memory _tokenIds
    ) public virtual payable {
        // 保管を確認
        (, uint256 payout) = SafeMathUpgradeable.tryMul(_tokenIds.length, unit * (10 ** 18));
        require(payout > 0, "invalid amount");
        require(ERC20Upgradeable(coin_token).balanceOf(address(this)) >= payout, "lack of change");
        // 関数の実行前に、残っているGASの量を取得する
        uint256 gasStart = gasleft();
        for (uint i = 0; i < _tokenIds.length; i++) {
            require(ownerOf(_tokenIds[i]) == msg.sender, "you are not owner"); // 所有権確認
            _transfer(msg.sender, address(this), _tokenIds[i]); // 紙幣預入
            custody.push(_tokenIds[i]); // 保管リストに追加
            _custodyCounter.increment();
        }

        // 払い出し
        (bool success, ) = coin_token.call(abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", address(this), msg.sender, payout));
        require(success, "External function execution failed payout");

        // 関数が使用したGASの量を計算する
        uint256 gasUsed = gasStart.sub(gasleft());

        // 未使用のETHを返還する
        uint256 refundAmount = msg.value.sub(gasUsed.mul(tx.gasprice));
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }
        emit Withdraw(payout);
    }

    function safeMint(address _to) internal virtual {
        // 現在のIDを取得
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(_to, tokenId);

        // インクリメント
        _tokenIdCounter.increment();
    }

    modifier onlyTrusted() {
        require(trusted[msg.sender] == true, "untrusted");
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
        require(_from == ownerOf(_tokenId), "invalid owner");
        _transfer(_from, _to, _tokenId);
    }

    function tokenExists(uint256 _tokenId) public virtual view returns(bool) {
        return _exists(_tokenId);
    }

    function _authorizeUpgrade(address) internal override virtual onlyOwner {}

}