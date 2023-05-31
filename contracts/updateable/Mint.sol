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
    event SetEnableNote(uint256 _unit, address indexed _contract);

    constructor() {}

    function initialize() public initializer {
        /**
         * ownerの設定とリエントランシ初期化のみ
         */
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
    function pause() public virtual onlyAdmin {
        require(!paused, "already paused");
        paused = true;
        emit Pause();
    }

    /**
     * 機能の解除
     */
    function restart() public virtual onlyAdmin {
        require(paused, "already started");
        paused = false;
        emit Restart();
    }

    /**
     * 使用可能な通貨トークンのアドレスを設定する
     */
    function setEnableCurrency(address _erc20address) public virtual onlyOwner {
        require(_erc20address != address(0), "invalid address");
        coin_token = _erc20address;
        emit SetEnableCurrency(_erc20address);
    }

    function getEnableCurrency() public view virtual returns(address) {
        return coin_token;
    }

    function setEnableNote(address _erc721address, uint256 _unit) public virtual onlyOwner {
        require(_erc721address != address(0), "invalid address");
        note_token[_unit] = _erc721address;
        emit SetEnableNote(_unit, _erc721address);
    }

    function isEnableNote(uint256 _unit) public view virtual returns(address) {
        return note_token[_unit];
    }

    /**
     * 使用可能なNFTのアドレスを設定する
     * 1: Mint可能
     * 2: Mint/Crossbreed可能
     */
    function setEnableItem(address _erc721address, bool _status) public virtual onlyOwner {
        require(_erc721address != address(0), "invalid address");
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
        require(proxyRegulationCanceled > 0 || agent[msg.sender] == true || owner() == msg.sender, "you don't have authority of proxy");
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
        address _agent,
        address _client,
        address _contract,
        uint256 _fee,
        uint256 _nonce,
        uint256 _code,
        uint256 _noteUnit,
        uint256 _noteId
    )
        nonReentrant
        onlyAgent
        external
        payable
        virtual
        returns(uint256)
    {
        require(_agent == msg.sender, "agent information is not match");
        checkProxyMint(_signature, _agent, _client, _contract, _fee, _nonce, _code, _noteUnit, _noteId);

        // 関数の実行前に、残っているGASの量を取得する
        uint256 gasStart = gasleft();

        // targetContractに外部関数呼び出しをする
        // fee支払い
        if (_fee > 0) {
            if (_noteId > 0 && _noteUnit > 0) {
                uint256 note_value = _noteUnit * (10 ** 18);
                _payFeeByNote(_client, _noteUnit, _noteId);
                _payCharge(_client, note_value.sub(_fee));
            } else {
                _payFee(_client, _fee);
            }
        }
        // 実行
        uint256 tokenId = _externalMint(_contract, _client, _code);

        signatures[_signature] = true;
        // 関数が使用したGASの量を計算する
        uint256 gasUsed = gasStart.sub(gasleft());

        // 未使用のETHを返還する
        uint256 refundAmount = msg.value.sub(gasUsed.mul(tx.gasprice));
        require(refundAmount <= msg.value, "overflow");
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }
        emit ProxyMint(_contract, _client, _fee, tokenId);
        return tokenId;
    }

    /**
     * バリデーション
     */
    function checkProxyMint(
        bytes memory _signature,
        address _agent,
        address _client,
        address _contract,
        uint256 _fee,
        uint256 _nonce,
        uint256 _code,
        uint256 _noteUnit,
        uint256 _noteId
    )
        public
        virtual
        view
        returns(bool)
    {
        require(!isPaused(), "paused");
        require(isEnableItem(_contract) , "disabled token");
        require(_fee >= minimumTxFee, "minimum Tx Fee");
        if (_noteId > 0 && _noteUnit > 0) {
            require(note_token[_noteUnit] != address(0), 'invalid note unit');
            require(IERC721Upgradeable(note_token[_noteUnit]).ownerOf(_noteId) == _client, "no ownership");
            uint256 noteValue = _noteUnit * (10 ** 18);
            require(noteValue >= _fee, "lack of note's value");
            (bool success, uint256 charges) = SafeMathUpgradeable.trySub(noteValue, _fee);
            require(success, "underflow");
            require(getCoinBalances(_agent) >= charges, "lack of charges");
        }
        address _from = checkProxyMintSignature(_signature, _contract, _fee, _nonce, _code, _noteUnit, _noteId);

        require(_from != address(0), "invalid signature");
        require(_from == _client, "address is not match");

        if (_noteId == 0) {
            require(getCoinBalances(_from) >= _fee, "lack of funds");
        }

        return true;
    }

    /**
     * 署名の検証
     */
    function checkProxyMintSignature(
        bytes memory _signature,
        address _contract,
        uint256 _fee,
        uint256 _nonce,
        uint256 _code,
        uint256 _noteUnit,
        uint256 _noteId
    ) public virtual view returns(address) {
        require(signatures[_signature] == false, "used signature");
        bytes32 hashedTx = proxyMintPreSignedHashing(_contract, _fee, _nonce, _code, _noteUnit, _noteId);
        address _from = ECDSAUpgradeable.recover(ECDSAUpgradeable.toEthSignedMessageHash(hashedTx), _signature);
        return _from;
    }

    function proxyMintPreSignedHashing(
        address _contract,
        uint256 _fee,
        uint256 _nonce,
        uint256 _code,
        uint256 _noteUnit,
        uint256 _noteId
    )
        private
        pure
        returns (bytes32)
    {
        /* "0x11d14e01": proxyMintPreSignedHashing(address,uint256,uint256,uint256,uint256,uint256) */
        return keccak256(abi.encodePacked(bytes4(0x11d14e01), _contract, _fee, _nonce, _code, _noteUnit, _noteId));
    }

    function _payFee(address _from, uint256 _fee) internal virtual{
        (bool success, ) = coin_token.call(abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", _from, msg.sender, _fee));
        require(success, "External function execution failed pay fee");
    }

    function _payFeeByNote(address _from, uint256 _noteUnit, uint256 _noteId) internal virtual{
        address note = note_token[_noteUnit];
        (bool success, ) = note.call(abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", _from, msg.sender, _noteId));
        require(success, "External function execution failed pay fee by note");
    }

    function _payCharge(address _to, uint256 _charge) internal virtual{
        (bool success, ) = coin_token.call(abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", msg.sender, _to, _charge));
        require(success, "External function execution failed pay charge");
    }

    function _externalMint(address _contract, address _owner, uint256 _code) internal virtual returns(uint256) {
        // mint実行
        (bool success, bytes memory res) = _contract.call(abi.encodeWithSignature("safeMint(address,uint256)", _owner, _code));
        require(success, "External function execution failed external mint");
        uint256 tokenId = abi.decode(res, (uint256));
        return tokenId;
    }

    function getCoinBalances(address _account) public view returns(uint256) {
        return IERC20Upgradeable(coin_token).balanceOf(_account);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}