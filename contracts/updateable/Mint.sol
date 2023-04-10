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
abstract contract Mint is UUPSUpgradeable, ReentrancyGuardUpgradeable, MintStorage {
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
     * 使用可能な通貨トークンのアドレスを設定する
     */
    function setEnableCurrency(address erc20address) public virtual onlyOwner {
        require(erc20address != address(0));
        currency_token = erc20address;
    }

    /**
     * 使用可能なNFTのアドレスを設定する
     */
    function setEnableItem(address erc721address, bool status) public virtual onlyOwner {
        require(erc721address != address(0));
        enable_tokens[erc721address] = status;
    }

    /**
     * 仲介制限解除設定
     */
    function changeProxyRegulation(uint8 status) public virtual onlyOwner {
        proxyRegulationCanceled = status;
    }

    /**
     * feeを払ってアイテムをMINTする
     */
    function proxyMint(
        bytes calldata _signature, // 署名
        address _contract,
        uint256 _tokenId,
        uint256 _fee,
        uint256 _nonce
    )
        nonReentrant
        onlyAdmin(1)
        external
        payable
        returns(bool)
    {
        address _from = checkProxyMint(_signature, _contract, _tokenId, _fee, _nonce);

        // 関数の実行前に、残っているGASの量を取得する
        uint256 gasStart = gasleft();

        // targetContractに外部関数呼び出しをする
        // fee支払い
        // _transfer(from, msg.sender, _fee); // fee支払い
        (bool success, ) = currency_token.call{value: msg.value}
                                (abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", _from, msg.sender, _fee));
        require(success, "External function execution failed");

        // 実行
        // require(IBlockSafari(_contract).externalMint(from, _tokenId));
        (bool success2, ) = _contract.call{value: msg.value}
                                (abi.encodeWithSignature("externalMint(address,uint256)", _from, _tokenId));
        require(success2, "External function execution failed 2");

        signatures[_signature] = true;

        // 関数が使用したGASの量を計算する
        uint256 gasUsed = gasStart.sub(gasleft());

        // 未使用のETHを返還する
        uint256 refundAmount = msg.value.sub(gasUsed.mul(tx.gasprice));
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }
        return true;
    }

    function checkProxyMint(
        bytes memory _signature,
        address _contract,
        uint256 _tokenId,
        uint256 _fee,
        uint256 _nonce
    )
        onlyAdmin(1)
        public
        view
        returns(address)
    {
        require(enable_tokens[_contract] == true, "disabled token");
        require(signatures[_signature] == false, "used signature");
        bytes32 hashedTx = proxyMintPreSignedHashing(_contract, _tokenId, _fee, _nonce);
        address _from = ECDSAUpgradeable.recover(hashedTx, _signature);
        require(_from != address(0), "invalid signature");
        require(IERC20Upgradeable(currency_token).balanceOf(_from) >= _fee, "lack of funds");
        require(_fee >= minimumTxFee, "minimum Tx Fee");

        return _from;
    }

    function proxyMintPreSignedHashing(
        address _contract,
        uint256 _tokenId,
        uint256 _fee,
        uint256 _nonce
    )
        internal
        pure
        returns (bytes32)
    {
        /* "0x92fac361": proxyMintPreSignedHashing(address,uint256,uint256,uint256) */
        return keccak256(abi.encodePacked(bytes4(0x92fac361), _contract, _tokenId, _fee, _nonce));
    }

    /**
     * feeを払ってアイテムをMINTする
     */
    function proxyCrossbreed(
        address _contract,
        CrossbreedSeed memory _parent1,
        CrossbreedSeed memory _parent2
    )
        nonReentrant
        onlyAdmin(1)
        isCrossbreedable(_parent1, _parent2)
        external
        payable
        returns(bool)
    {
        (address _parentOwner1, address _parentOwner2) = checkProxyCrossbreed(_contract, _parent1, _parent2);

        // 関数の実行前に、残っているGASの量を取得する
        uint256 gasStart = gasleft();

        // targetContractに外部関数呼び出しをする
        // fee支払い
        // _transfer(from, msg.sender, _fee); // fee支払い
        bool success;
        (success, ) = currency_token.call{value: msg.value}
                                (abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", _parentOwner1, msg.sender, _parent1.fee));
        require(success, "External function execution failed");
        (success, ) = currency_token.call{value: msg.value}
                                (abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", _parentOwner2, msg.sender, _parent2.fee));
        require(success, "External function execution failed");

        // 実行
        // require(IBlockSafari(_contract).externalMint(from, _tokenId));
        (success, ) = _contract.call{value: msg.value}
                                (abi.encodeWithSignature("externalMint(address,uint256)", _parentOwner1, _parent1.newBorn));
        require(success, "External function execution failed 2");
        (success, ) = _contract.call{value: msg.value}
                                (abi.encodeWithSignature("externalMint(address,uint256)", _parentOwner2, _parent2.newBorn));
        require(success, "External function execution failed 2");

        _afterProcess(_parent1.newBorn, _parent1.parentTokenId, _parent1.partnerTokenId);
        _afterProcess(_parent2.newBorn, _parent2.parentTokenId, _parent1.partnerTokenId);

        signatures[_parent1.signature] = true;
        signatures[_parent2.signature] = true;

        // 関数が使用したGASの量を計算する
        uint256 gasUsed = gasStart.sub(gasleft());

        // 未使用のETHを返還する
        uint256 refundAmount = msg.value.sub(gasUsed.mul(tx.gasprice));
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }
        return true;
    }

    function checkProxyCrossbreed(
        address _contract,
        CrossbreedSeed memory _parent1,
        CrossbreedSeed memory _parent2
    )
        onlyAdmin(1)
        isCrossbreedable(_parent1, _parent2)
        public
        view
        returns(address, address)
    {
        require(enable_tokens[_contract] == true, "disabled token");
        require(_parent1.parentTokenId != _parent2.parentTokenId);
        require(_parent1.parentTokenId == _parent2.partnerTokenId && _parent2.parentTokenId == _parent1.partnerTokenId, "invalid transaction");
        require(_parent1.fee.add(_parent2.fee) >= minimumTxFee, "minimum Tx Fee");

        address _parentOwner1 = _authCrossbreed(_contract, _parent1);
        address _parentOwner2 = _authCrossbreed(_contract, _parent2);
        return (_parentOwner1, _parentOwner2);
    }

    modifier isCrossbreedable(CrossbreedSeed memory _seed1, CrossbreedSeed memory _seed2) {
        require(isCrossbreedLocked(_seed1.parentTokenId));
        require(isCrossbreedLocked(_seed2.parentTokenId));
        require(!isFamily(_seed1.parentTokenId, _seed2.parentTokenId));
        _;
    }

    function isFamily(uint256 _tokenId, uint256 _targetId) public view virtual returns(bool) {
        uint256[4] memory parents = [
            family[_tokenId][0],
            family[_tokenId][1],
            family[_targetId][0],
            family[_targetId][1]
        ];
        for (uint8 i = 0; i < parents.length; i++) {
            if (parents[i] == _targetId) {
                return true;
            }
            (uint256[] memory parents2) = getParents(parents[i]);
            for (uint8 j = 0; j < parents2.length; i++) {
                if (parents2[j] == _targetId) {
                    return true;
                }
            }
        }
        return false;
    }

    function isCrossbreedLocked(uint256 _tokenId) public view virtual returns(bool) {
        if (block.timestamp > crossbreedLock[_tokenId]) {
            return true;
        } else {
            return false;
        }
    }

    function _authCrossbreed(address _contract, CrossbreedSeed memory _crossbreedSeed) internal view returns(address) {
        require(signatures[_crossbreedSeed.signature] == false, "used signature");
        bytes32 hashedTx = proxyCrossbreedPreSignedHashing(_contract, _crossbreedSeed);
        address _from = ECDSAUpgradeable.recover(hashedTx, _crossbreedSeed.signature);
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
        pure
        returns (bytes32)
    {
        /* "0x11d14e01": proxyMintPreSignedHashing(address,uint256,uint256,uint256,uint256) */
        return keccak256(abi.encodePacked(bytes4(0x11d14e01), _contract, _seed.parentTokenId, _seed.partnerTokenId, _seed.fee, _seed.nonce));
    }

    function _afterProcess(uint256 tokenId, uint256 _parentTokenId, uint256 _partnerTokenId) internal
    {
        // 父母の登録
        family[tokenId][0] = _parentTokenId;
        family[tokenId][1] = _partnerTokenId;

        crossbreedLock[_parentTokenId] = block.timestamp + (crossbreedLockDays * 24 * 60 * 60);
    }

    function getParents(uint256 tokenId) public view virtual returns(uint256[] memory){
        return family[tokenId];
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}