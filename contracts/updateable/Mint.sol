// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../storage/MintStorage.sol";

/**
 * Market Contract
 */
contract Mint is UUPSUpgradeable, ReentrancyGuardUpgradeable, MintStorage {
    using SafeMathUpgradeable for uint256;
    using ECDSAUpgradeable for bytes32;

    event Pause();
    event Restart();
    event SetEnableItem(address indexed _contract, bool _status);
    event SetEnableCurrency(address indexed _contract);
    event ChangeProxyRegulationCanceled(uint8 status);
    event ProxyMint(address indexed _contract, address indexed _from, uint256 _fee, uint256 tokenId);

    constructor() {}

    function initialize() public initializer {
        /**
         * 1XAFARI ≒ 0.15MATIC(150000000000000000)
         * 販売額*合計手数料率/100がminimumTxFee以上である必要がある
         *
         * 購入の代行は「(販売額*合計手数料率/100)*purchaseFeeRate/100」となる
         */
        admin[0][msg.sender] = true;
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
        emit Pause();
    }

    /**
     * 機能の解除
     */
    function restart() public virtual onlyAdmin(0) {
        require(paused);
        paused = false;
        emit Restart();
    }

    /**
     * 使用可能な通貨トークンのアドレスを設定する
     */
    function setEnableCurrency(address _erc20address) public virtual onlyOwner {
        require(_erc20address != address(0));
        currency_token = _erc20address;
        emit SetEnableCurrency(_erc20address);
    }

    function getEnableCurrency() public view virtual returns(address) {
        return currency_token;
    }

    /**
     * 使用可能なNFTのアドレスを設定する
     * 1: Mint可能
     * 2: Mint/Crossbreed可能
     */
    function setEnableItem(address _erc721address, bool _status) public virtual onlyOwner {
        require(_erc721address != address(0));
        enable_tokens[_erc721address] = _status;
        emit SetEnableItem(_erc721address, _status);
    }

    function isEnableItem(address _erc721address) public view virtual returns(bool) {
        return enable_tokens[_erc721address];
    }

    /**
     * 仲介制限解除設定
     */
    function changeProxyRegulation(uint8 _status) public virtual onlyOwner {
        proxyRegulationCanceled = _status;
        emit ChangeProxyRegulationCanceled(_status);
    }

    function getProxyRegulationCanceled() public view virtual returns(uint8) {
        return proxyRegulationCanceled;
    }

    function setMinimumTxFee(uint256 _value) public virtual onlyOwner {
        minimumTxFee = _value;
    }

    function getMinimumTaxFee() public virtual view returns(uint256) {
        return minimumTxFee;
    }

    modifier onlyAgent() {
        require(proxyRegulationCanceled > 0 || admin[1][msg.sender] == true || owner() == msg.sender, "you don't have authority of proxy");
        _;
    }

    /**
     * feeを払ってアイテムをMINTする
     * Mint後に運営を仲介したTxからtokenIdが返され、
     * 運営がtokenIdをtokenCodeと紐づける
     * tokenIdをMintすることで出現したAnimalsを確認できる１
     */
    function proxyMint(
        bytes memory _signature, // 署名
        address _contract,
        uint256 _fee,
        uint256 _nonce,
        uint256 _code
    )
        nonReentrant
        onlyAgent
        external
        payable
        virtual
        returns(uint256)
    {
        (, address _from) = checkProxyMint(_signature, _contract, _fee, _nonce, _code);

        // 関数の実行前に、残っているGASの量を取得する
        uint256 gasStart = gasleft();

        // targetContractに外部関数呼び出しをする
        // fee支払い
        if (_fee > 0) {
            _payFee(_from, _fee);
        }
        // 実行
        uint256 tokenId = _externalMint(_contract, _from, _code);

        signatures[_signature] = true;

        // 関数が使用したGASの量を計算する
        uint256 gasUsed = gasStart.sub(gasleft());

        // 未使用のETHを返還する
        uint256 refundAmount = msg.value.sub(gasUsed.mul(tx.gasprice));
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }
        emit ProxyMint(_contract, _from, _fee, tokenId);
        return tokenId;
    }

    function checkProxyMint(
        bytes memory _signature,
        address _contract,
        uint256 _fee,
        uint256 _nonce,
        uint256 _code
    )
        public
        virtual
        view
        returns(bool, address)
    {
        require(isEnableItem(_contract) , "disabled token");
        address _from = checkProxyMintSignature(_signature, _contract, _fee, _nonce, _code);
        require(_from != address(0), "invalid signature");
        require(IERC20Upgradeable(currency_token).balanceOf(_from) >= _fee, "lack of funds");
        require(_fee >= minimumTxFee, "minimum Tx Fee");

        return (true, _from);
    }

    function checkProxyMintSignature(
        bytes memory _signature,
        address _contract,
        uint256 _fee,
        uint256 _nonce,
        uint256 _code
    ) public virtual view returns(address) {
        require(signatures[_signature] == false, "used signature");
        bytes32 hashedTx = proxyMintPreSignedHashing(_contract, _fee, _nonce, _code);
        address _from = ECDSAUpgradeable.recover(ECDSAUpgradeable.toEthSignedMessageHash(hashedTx), _signature);
        return _from;
    }

    function proxyMintPreSignedHashing(
        address _contract,
        uint256 _fee,
        uint256 _nonce,
        uint256 _code
    )
        public
        virtual
        pure
        returns (bytes32)
    {
        /* "0x92fac361": proxyMintPreSignedHashing(address,uint256,uint256,uint256) */
        return keccak256(abi.encodePacked(bytes4(0x92fac361), _contract, _fee, _nonce, _code));
    }

    function _payFee(address _from, uint256 _fee) internal virtual{
        (bool success, ) = currency_token.call(abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", _from, msg.sender, _fee));
        require(success, "External function execution failed pay fee");
    }

    function _externalMint(address _contract, address _owner, uint256 _code) internal virtual returns(uint256) {
        // mint実行
        (bool success, bytes memory res) = _contract.call(abi.encodeWithSignature("safeMint(address,uint256)", _owner, _code));
        require(success, "External function execution failed external mint");
        uint256 tokenId = abi.decode(res, (uint256));
        return tokenId;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}