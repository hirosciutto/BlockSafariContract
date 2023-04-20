// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../storage/MarketStorage.sol";

/**
 * Market Contract
 */
abstract contract Market is UUPSUpgradeable, ReentrancyGuardUpgradeable, MarketStorage {
    using SafeMathUpgradeable for uint256;
    using ECDSAUpgradeable for bytes32;

    event AgentList(address indexed _from, uint256 _tokenId, uint256 _amount, address _agent);
    event AgentPurchase(address indexed _from, address indexed _to, uint256 _tokenId, uint256 _amount);
    event ExternalMint(address indexed _minter, uint256 _tokenId);

    constructor() {}

    function initialize() public initializer {
        /**
         * 1XAFARI ≒ 0.15MATIC(150000000000000000)
         * 販売額*合計手数料率/100がminimumTxFee以上である必要がある
         *
         * 購入の代行は「(販売額*合計手数料率/100)*purchaseFeeRate/100」となる
         */
        admin[0][msg.sender] = true;
        minimumTxFee = 1; // 1XAFARI
        purchaseFeeRate = 80; // 80%
        __Ownable_init();
        __ReentrancyGuard_init();
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
    function pause() public virtual onlyAdmin(0) {
        require(!paused);
        paused = true;
    }

    /**
     * 機能の解除
     */
    function restart() public virtual onlyAdmin(0) {
        require(paused);
        paused = false;
    }

    /**
     * 使用可能な通貨トークンのアドレスを設定する
     */
    function setEnableCurrency(address erc20address) public virtual onlyOwner {
        require(erc20address != address(0));
        currency_token = erc20address;
    }

    /**
     * 使用可能なNFTのアドレスを設定する
     */
    function setEnableItem(address erc721address, uint8 status) public virtual onlyOwner {
        require(erc721address != address(0));
        enable_tokens[erc721address] = status;
    }

    /**
     * 販売制限解除設定
     */
    function changeSalesRegulation(uint8 status) public virtual onlyOwner {
        salesRegulationCanceled = status;
    }

    /**
     * 仲介制限解除設定
     */
    function changeProxyRegulation(uint8 status) public virtual onlyOwner {
        proxyRegulationCanceled = status;
    }

    modifier onlyAgent() {
        require(proxyRegulationCanceled > 0 || admin[1][msg.sender] == true || owner() == msg.sender, "you don't have authority of proxy");
        _;
    }


    /**
     * 出品
     * 販売者の指定した[アドレス/トークンID]のNFTをapprove
     */
    function agentList(
        bytes calldata _signature,
        address _nftAddress,
        uint256 _tokenId,
        uint8 _feeRate,
        uint256 _value,
        uint256 _nonce
    )
        nonReentrant
        external
        virtual
        payable
    {
        (,address seller) = checkAgentList(_signature, _nftAddress, _tokenId, _feeRate, _value, _nonce);

        _saveListing(_nftAddress, seller, _tokenId, _feeRate, _value);

        signatures[_signature] = true;
    }

    function checkAgentList(
        bytes calldata _signature,
        address _nftAddress,
        uint256 _tokenId,
        uint8 _feeRate,
        uint256 _value,
        uint256 _nonce
    )
        public
        view
        onlyAdmin(1)
        returns(bool, address)
    {
        require(isSaleableItemContract(_nftAddress), "invalid nft token");
        require(signatures[_signature] == false, "used signature");
        require(_value > 0, "cannot sell free");
        require(_value.mul(_feeRate).div(100) >= minimumTxFee, "lack of fee");
        bytes32 hashedTx = agentListPreSignedHashing(_nftAddress, _tokenId, _feeRate, _value, _nonce);
        address seller = ECDSAUpgradeable.recover(hashedTx, _signature);
        require(seller != address(0), "invalid signature");
        return (true, seller);
    }

    function isSaleableItemContract(address _contract) public view returns(bool) {
        if (enable_tokens[_contract] > 0) {
            return true;
        } else {
            return false;
        }
    }

    function agentListPreSignedHashing(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _feeRate,
        uint256 _value,
        uint256 _nonce
    )
        internal
        pure
        returns (bytes32)
    {
        /* "0xa358f09e": agentListPreSignedHashing(address,uint256,uint256,uint256,uint256) */
        return keccak256(abi.encodePacked(bytes4(0xbbfee4d4), _nftAddress, _tokenId, _feeRate, _value, _nonce));
    }

    function _saveListing(
        address _nftAddress,
        address _from,
        uint256 _tokenId,
        uint8 _feeRate,
        uint256 _value
    )
        internal
        virtual
    {
        require(!paused, "this contract is paused now");
        // 販売規制解除前はcontract ownerかadminのみが販売元足りえる
        require(salesRegulationCanceled > 0 || admin[0][_from] == true || owner() == _from, "you don't have authority of sale");
        require(IERC721Upgradeable(_nftAddress).ownerOf(_tokenId) == _from, "not owned"); // NFTの所有確認

        // 金額を指定
        itemOnSale[currency_token][_from][_tokenId].value = _value;
        // 実行者を記録
        itemOnSale[currency_token][_from][_tokenId].sender = msg.sender;
        // feeRate記録
        itemOnSale[currency_token][_from][_tokenId].feeRate = _feeRate;
    }

    function agentPurchase(
        bytes calldata _signature,
        address _nftAddress,
        uint256 _tokenId,
        uint256 _value,
        uint256 _nonce
    )
        nonReentrant
        external
        virtual
        payable
    {
        (, address seller, address customer) = checkAgentPurchase(_signature, _nftAddress, _tokenId, _value, _nonce);

        // 関数の実行前に、残っているGASの量を取得する
        uint256 gasStart = gasleft();

        // targetContractに外部関数呼び出しをする
        // 代金支払い
        _payment(_nftAddress, _tokenId, seller, customer, _value);
        // 商品譲渡
        _deliveryItem(_nftAddress, _tokenId, seller);
        // fee支払い
        _payListFee(_nftAddress, _tokenId, seller, customer, _value);
        _payPurchaseFee(_nftAddress, _tokenId, seller, customer, _value);

        // 関数が使用したGASの量を計算する
        uint256 gasUsed = gasStart.sub(gasleft());

        // 未使用のETHを返還する
        uint256 refundAmount = msg.value.sub(gasUsed.mul(tx.gasprice));
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }
    }

    function checkAgentPurchase(
        bytes memory _signature,
        address _nftAddress,
        uint256 _tokenId,
        uint256 _value,
        uint256 _nonce
    )
        onlyAgent
        public
        virtual
        returns(bool, address, address)
    {
        require(isSaleableItemContract(_nftAddress), "disabled token");
        require(signatures[_signature] == false, "used signature");
        require(_value > 0, "cannot sell free");
        address customer = ECDSAUpgradeable.recover(agentPurchasePreSignedHashing(_nftAddress, _tokenId, _value, _nonce), _signature);
        require(customer != address(0), "invalid signature");
        address seller = IERC721Upgradeable(_nftAddress).ownerOf(_tokenId);
        require(seller != address(0), "invalid purchase");
        return (true, seller, customer);
    }

    function agentPurchasePreSignedHashing(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _value,
        uint256 _nonce
    )
        internal
        pure
        returns (bytes32)
    {
        /* "0x7dc15f66": agentPurchasePreSignedHashing(address,uint256,uint256,uint256) */
        return keccak256(abi.encodePacked(bytes4(0x7dc15f66), _nftAddress, _tokenId, _value, _nonce));
    }

    function _payment(address _nftAddress, uint256 _tokenId, address _seller, address _customer, uint256 _value) public payable {
        uint8 feeRate = itemOnSale[_nftAddress][_seller][_tokenId].feeRate;
        uint256 profit = _value.sub(_value.mul(feeRate).div(100));
        (bool success, ) = currency_token.call{value: msg.value}
                                (abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", _customer, _seller, profit));
        require(success, "External function execution failed 1");
    }

    function _payListFee(address _nftAddress, uint256 _tokenId, address _seller,  address _customer, uint256 _value) public payable {
        uint8 feeRate = itemOnSale[_nftAddress][_seller][_tokenId].feeRate;
        address listingAgent = itemOnSale[_nftAddress][_seller][_tokenId].sender;
        uint256 salesProxyFee = (_value.mul(feeRate).div(100)).sub((_value.mul(feeRate).div(100)).mul(purchaseFeeRate).div(100)); // 販売手数料 = 合計手数料 - 購入手数料
        (bool success, ) = currency_token.call{value: msg.value}
                                (abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", _customer, listingAgent, salesProxyFee));
        require(success, "External function execution failed 3");
    }

    function _payPurchaseFee(address _nftAddress, uint256 _tokenId, address _seller,  address _customer, uint256 _value) public payable {
        uint8 feeRate = itemOnSale[_nftAddress][_seller][_tokenId].feeRate;
        uint256 purchaseProxyFee = (_value.mul(feeRate).div(100)).mul(purchaseFeeRate).div(100); // 購入手数料 = 合計手数料の80%
        (bool success, ) = currency_token.call{value: msg.value}
                                (abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", _customer, msg.sender, purchaseProxyFee));
        require(success, "External function execution failed 4");
    }

    function _deliveryItem(address _nftAddress, uint256 _tokenId, address _seller) public payable {
        (bool success, ) = _nftAddress.call{value: msg.value}
                                (abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", _seller, msg.sender, _tokenId));
        require(success, "External function execution failed 2");
    }

    /**
     * 出品を確認
     */
    function checkSale(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _amount
    )
        public
        virtual
        view
        returns(address, address, uint256, uint256)
    {
        require(isSaleableItemContract(_nftAddress), "disabled token");
        address _seller = IERC721Upgradeable(_nftAddress).ownerOf(_tokenId);
        if (itemOnSale[_nftAddress][_seller][_tokenId].value >= _amount) {
            return (
                _seller, // 販売者
                itemOnSale[_nftAddress][_seller][_tokenId].sender, // 代行者
                itemOnSale[_nftAddress][_seller][_tokenId].feeRate, // 手数料率
                itemOnSale[_nftAddress][_seller][_tokenId].value // 金額
            );
        } else {
            return (address(0), address(0), 0, 0);
        }
    }

    function calcFee(
        uint256 _value,
        uint256 _feeRate
    )
        public
        view
        returns(uint256, uint256, uint256)
    {
        uint256 totalFee = _value.mul(_feeRate).div(100);
        uint256 profit = _value.sub(totalFee); // 利益 = 合計金額 - 合計手数料
        uint256 purchaseProxyFee = totalFee.mul(purchaseFeeRate).div(100); // 購入手数料 = 合計手数料の80%

        uint256 salesProxyFee = totalFee.sub(purchaseProxyFee); // 販売手数料 = 合計手数料 - 購入手数料
        return (profit, purchaseProxyFee, salesProxyFee);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}