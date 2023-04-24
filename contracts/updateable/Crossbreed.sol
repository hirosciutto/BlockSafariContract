// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../storage/CrossbreedStorage.sol";

/**
 * Crossbreed Contract
 */
contract Crossbreed is UUPSUpgradeable, ReentrancyGuardUpgradeable, CrossbreedStorage {
    using SafeMathUpgradeable for uint256;
    using ECDSAUpgradeable for bytes32;

    event Pause();
    event Restart();
    event SetEnableItem(address indexed _contract, bool _status);
    event SetEnableCurrency(address indexed _contract);
    event ChangeProxyRegulationCanceled(uint8 status);
    event ProxyMint(address indexed _contract, address indexed _from, uint256 _fee, uint256 tokenId);
    event ProxyCrossbreed(address indexed _contract, address indexed _parentOwner1, address indexed _parentOwner2, CrossbreedSeed seed1, CrossbreedSeed seed2);

    constructor() {}

    function initialize() public initializer {
        /**
         * 1XAFARI ≒ 0.15MATIC(150000000000000000)
         * 販売額*合計手数料率/100がminimumTxFee以上である必要がある
         *
         * 購入の代行は「(販売額*合計手数料率/100)*purchaseFeeRate/100」となる
         */
        admin[0][msg.sender] = true;
        crossbreedLockDays = 60; // 60日
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
     */
    function proxyCrossbreed(
        address _contract,
        bytes memory _signature1,
        bytes memory _signature2,
        CrossbreedSeed memory _parent1,
        CrossbreedSeed memory _parent2
    )
        nonReentrant
        onlyAgent
        external
        virtual
        payable
        returns(bool)
    {
        (, address _parentOwner1, address _parentOwner2) = checkProxyCrossbreed(_contract, _signature1, _signature2, _parent1, _parent2);

        // 関数の実行前に、残っているGASの量を取得する
        uint256 gasStart = gasleft();

        _payFee(_parentOwner1, _parent1.fee);
        _payFee(_parentOwner2, _parent2.fee);

        uint256 tokenId1 = _externalMint(_contract, _parentOwner1);
        _afterProcess(_contract, tokenId1, _parent1.parentTokenId, _parent1.partnerTokenId);

        uint256 tokenId2 = _externalMint(_contract, _parentOwner2);
        _afterProcess(_contract, tokenId2, _parent2.parentTokenId, _parent2.partnerTokenId);

        signatures[_signature1] = true;
        signatures[_signature2] = true;

        // 関数が使用したGASの量を計算する
        uint256 gasUsed = gasStart.sub(gasleft());

        // 未使用のETHを返還する
        uint256 refundAmount = msg.value.sub(gasUsed.mul(tx.gasprice));
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }
        emit ProxyCrossbreed(_contract, _parentOwner1, _parentOwner2, _parent1, _parent2);
        return true;
    }

    function checkProxyCrossbreed(
        address _contract,
        bytes memory _signature1,
        bytes memory _signature2,
        CrossbreedSeed memory _parent1,
        CrossbreedSeed memory _parent2
    )
        isCrossbreedable(_contract, _parent1, _parent2)
        public
        virtual
        view
        returns(bool, address, address)
    {
        require(isEnableItem(_contract), "disabled token");
        require(_parent1.parentTokenId != _parent2.parentTokenId);
        require(_parent1.parentTokenId == _parent2.partnerTokenId && _parent2.parentTokenId == _parent1.partnerTokenId, "invalid transaction");
        require(_parent1.fee.add(_parent2.fee) >= minimumTxFee, "minimum Tx Fee");

        address _parentOwner1 = _authCrossbreed(_contract, _signature1, _parent1);
        address _parentOwner2 = _authCrossbreed(_contract, _signature2, _parent2);
        return (true, _parentOwner1, _parentOwner2);
    }

    modifier isCrossbreedable(address _contract, CrossbreedSeed memory _seed1, CrossbreedSeed memory _seed2) {
        require(isCrossbreedLocked(_contract, _seed1.parentTokenId));
        require(isCrossbreedLocked(_contract, _seed2.parentTokenId));
        require(!isFamily(_contract, _seed1.parentTokenId, _seed2.parentTokenId));
        _;
    }

    function isFamily(address _contract, uint256 _tokenId, uint256 _targetId) public virtual view returns(bool) {
        uint256[4] memory parents = [
            family[_contract][_tokenId][0],
            family[_contract][_tokenId][1],
            family[_contract][_targetId][0],
            family[_contract][_targetId][1]
        ];
        for (uint8 i = 0; i < parents.length; i++) {
            if (parents[i] == _targetId) {
                return true;
            }
            (uint256[] memory parents2) = getParents(_contract, parents[i]);
            for (uint8 j = 0; j < parents2.length; i++) {
                if (parents2[j] == _targetId) {
                    return true;
                }
            }
        }
        return false;
    }

    function isCrossbreedLocked(address _contract, uint256 _tokenId) public virtual view returns(bool) {
        if (block.timestamp > crossbreedLock[_contract][_tokenId]) {
            return true;
        } else {
            return false;
        }
    }

    function _payFee(address _from, uint256 _fee) internal virtual {
        (bool success, ) = currency_token.call(abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", _from, msg.sender, _fee));
        require(success, "External function execution failed pay fee");
    }

    function _externalMint(address _contract, address _owner) internal virtual returns(uint256) {
        // mint実行
        (bool success, bytes memory res) = _contract.call(abi.encodeWithSignature("safeMint(address)", _owner));
        require(success, "External function execution failed external mint");
        uint256 tokenId = abi.decode(res, (uint256));
        return tokenId;
    }

    function _authCrossbreed(address _contract, bytes memory _signature, CrossbreedSeed memory _crossbreedSeed) internal virtual view returns(address) {
        require(signatures[_signature] == false, "used signature");
        bytes32 hashedTx = proxyCrossbreedPreSignedHashing(_contract, _crossbreedSeed);
        address _from = ECDSAUpgradeable.recover(hashedTx, _signature);
        require(_from != address(0), "invalid signature");
        require(IERC20Upgradeable(currency_token).balanceOf(_from) >= _crossbreedSeed.fee, "lack of funds");
        require(IERC721Upgradeable(_contract).ownerOf(_crossbreedSeed.parentTokenId) == _from, "parent is invalid owner");
        return _from;
    }

    function proxyCrossbreedPreSignedHashing(
        address _contract,
        CrossbreedSeed memory _seed
    )
        public
        virtual
        pure
        returns (bytes32)
    {
        /* "0x361c4ee6": proxyCrossbreedPreSignedHashing(address,tuple()) */
        return keccak256(abi.encodePacked(bytes4(0x361c4ee6), _contract, _seed.parentTokenId, _seed.partnerTokenId, _seed.fee, _seed.nonce));
    }

    function _afterProcess(address _contract, uint256 _tokenId, uint256 _parentTokenId, uint256 _partnerTokenId) internal virtual
    {
        // 父母の登録
        family[_contract][_tokenId][0] = _parentTokenId;
        family[_contract][_tokenId][1] = _partnerTokenId;

        crossbreedLock[_contract][_parentTokenId] = block.timestamp + (crossbreedLockDays * 24 * 60 * 60);
    }

    function getParents(address _contract, uint256 tokenId) public view virtual returns(uint256[] memory){
        return family[_contract][tokenId];
    }

    function getCrossbreedUnlockDate(address _contract, uint256 _tokenId) public view virtual returns(uint256) {
        return crossbreedLock[_contract][_tokenId];
    }

    function updateCrossbreedLockDays(uint8 _days) public virtual onlyOwner {
        crossbreedLockDays = _days;
    }

    function _authorizeUpgrade(address) internal override virtual onlyOwner {}
}