// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../utils/ERC721Wrapper.sol";
import "@openzeppelin/contracts-upgradeable/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMath.sol";

contract Sale is ERC721Wrapper {

    event List(address indexed _from, uint256 _tokenId, uint256 _amount);
    event AgentList(address indexed _from, uint256 _tokenId, uint256 _amount, address _agent);
    event ExternalBuy(address indexed _from, address indexed _to, uint256 _tokenId, uint256 _amount);

    modifier onlyToken() {
        require(currency_token == msg.sender);
        _;
    }

    /**
     * 機能停止中か確認
     */
    function isPaused() public view virtual returns(bool) {
        return paused;
    }

    /**
     * 機能の停止
     */
    function pause() public virtual onlyOwner {
        require(!paused);
        paused = true;
    }

    /**
     * 機能の解除
     */
    function restart() public virtual onlyOwner {
        require(paused);
        paused = false;
    }

    /**
     * 使用可能なトークンのアドレスを設定する
     */
    function setEnableToken(address erc20address) public virtual onlyOwner {
        require(erc20address != address(0));
        currency_token = erc20address;
    }

    function changeSalesRegulation(uint8 status) public virtual onlyOwner {
        salesRegulationCanceled = status;
    }

    function changeAgentListRegulation(uint8 status) public virtual onlyOwner {
        agentListRegulationCanceled = status;
    }

    /**
     * 指定アドレスのトークン所有履歴のリストを取得
     */
    function getAssetLog(address _target) public virtual returns(uint256[] memory) {
        return assetLog[_target];
    }

    /**
    * 指定アドレスから出品中の商品を取得
    */
    function getListed(address _target) public view virtual returns (uint256[] memory) {
        // 指定アドレスの所有履歴を取得
        uint256[] memory logs = getAssetLog(_target);

        // 指定アドレスの現在の販売数を取得
        uint256 counter = 0;
        for (uint256 i = 0; i < logs.length; i++) {
            if (itemOnSale[currency_token][_target][logs[i]].value > 0 && _owners[logs[i]] == _target) {
                counter++;
            }
        }
        // 配列の要素数を販売数で絞った変数を作成
        uint256[] memory onSaleList = new uint256[](counter);
        // 上記の変数に出品アイテムを設置する
        counter = 0;
        for (uint256 i = 0; i < logs.length; i++) {
            if (itemOnSale[currency_token][_target][logs[i]].value > 0 && _owners[logs[i]] == _target) {
                onSaleList[counter] = logs[i];
                counter++;
            }
        }
        return onSaleList;
    }

    /**
     * 出品を確認
     */
    function checkSale(address _currency, uint256 _tokenId, uint256 _amount) public returns(address, address, uint256) {
        address _seller = ownerOf(_tokenId);
        if (_currency == currency_token && itemOnSale[currency_token][_seller][_tokenId].value > _amount) {
            return (
                _seller,
                itemOnSale[currency_token][_seller][_tokenId].sender,
                itemOnSale[currency_token][_seller][_tokenId].feeRate
            );
        } else {
            return (address(0), address(0), 0);
        }
    }

    /**
    * 指定の金額で出品
    * gasが必要だが手数料は2.5%
    */
    function list(
        uint256 _tokenId, // 売りたいトークン
        uint256 _feeRate, // 何パーセントを仲介者に支払うか
        uint256 _value, // いくら(トークン単位)で売りたいか
        uint256 _nonce
    )
        external
        virtual
    {
        _list(msg.sender, _tokenId, _feeRate, _value);
        signatures[_signature] = true;
        emit List(msg.sender, _tokenId, _value);
    }

    /**
    * 指定の金額で出品
    * 無料で出品できるが、購入額の5%が手数料として差し引かれる
    */
    function agentList(
        bytes calldata _signature, // 署名
        uint256 _tokenId, // 売りたいトークン
        uint256 _feeRate, // 何パーセントを仲介者に支払うか
        uint256 _value, // いくら(トークン単位)で売りたいか
        uint256 _nonce
    )
        external
        virtual
    {
        require(_admin[1][msg.sender] == true || agentListRegulationCanceled, "you are not agent");
        require(signatures[_signature] == false, "used signature");
        require(_value > 0, "cannot sell free");
        bytes32 hashedTx = agentPutUpPreSignedHashing(_tokenId, _feeRate, _value, _nonce);
        address from = ECDSA.recover(hashedTx, _signature);
        require(from != address(0), "invalid signature");

        _list(from, _tokenId, _feeRate, _value);
        signatures[_signature] = true;
        emit AgentList(from, _tokenId, _value, msg.sender);
    }

    function agentListPreSignedHashing(
        uint256 _tokenId,
        uint256 _feeRate,
        uint256 _value,
        uint256 _nonce
    )
        private
        pure
        virtual
        returns (bytes32)
    {
        /* "0xbbfee4d4": agentListPreSignedHashing(uint256,uint256,uint256,uint256) */
        return keccak256(abi.encodePacked(bytes4(0xbbfee4d4), _tokenId, _feeRate, _value, _nonce));
    }

    function _list(
        address _from,
        uint256 _tokenId,
        uint256 _feeRate,
        uint256 _value,
    )
        external
        virtual
    {
        require(!paused, "this contract is paused now");
        require(salesRegulationCanceled > 0 || _admin[0][_from] || _owner == _from, "you don't have authority of sale");
        require(ownerOf(_tokenId) == _from, "not owned"); // NFTの所有確認
        require(_feeRate > 0 && _feeRate < 100, "invalid fee rate");

        // 金額を指定
        itemOnSale[currency_token][_from][_tokenId].value = _value;
        // 実行者を記録
        itemOnSale[currency_token][_from][_tokenId].sender = msg.sender;
        // feeRate記録
        itemOnSale[currency_token][_from][_tokenId].feeRate = _feeRate;
    }

    /**
     * 出品の取り下げ
     */
    function stopListing(uint256 _tokenId) public virtual {
        require(!paused, "this contract is paused now");
        require(itemOnSale[currency_token][msg.sender][_tokenId].value > 0, "you are not listing");
        _stopListing(msg.sender, _tokenId);
    }

    function _stopListing(address _seller, uint256 _tokenId) internal virtual {
        require(currency_token != address(0), "this token is disabled");
        require(_seller != address(0), "invalid seller");
        require(_tokenId > 0, "invalid token id");
        itemOnSale[currency_token][_seller][_tokenId].value = 0;
        emit List(_seller, _tokenId, 0);
    }

    /**
    * 指定の金額で購入
    */
    function externalBuy(
        address _purchaser,
        address _seller
        uint256 _tokenId
    )
        external
        virtual
        onlyToken
        returns(bool)
    {
        require(!paused, "this contract is paused now");
        require(itemOnSale[currency_token][_seller][_tokenId].value > 0, "not in sale");
        _safeTransfer(from, _to, _tokenId, data);
        uint256 amount = itemOnSale[currency_token][_seller][_tokenId].value;
        _stopListing(_seller, _tokenId);
        emit ExternalBuy(_purchaser, _seller, _tokenId, amount);
        return true;
    }

    /**
    * 外部からのmint要請
    */
    function externalMint(
        address _minter
        uint256 _tokenId
    )
        external
        virtual
        onlyToken
        returns(bool)
    {
        require(!paused, "this contract is paused now");
        _safeMint(_minter, tokenId);
        return true;
    }
}