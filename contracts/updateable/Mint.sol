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
    event SetEnableItem(address indexed _contract, uint8 _status);
    event SetEnableCurrency(address indexed _contract);
    event ChangeProxyRegulationCanceled(uint8 status);
    event ProxyMint(address indexed _contract, address indexed _from, uint256 tokenId, uint256 _fee, uint256 _nonce);
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
        minimumTxFee = 10 ** 18; // 1XAFARI
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
    function setEnableItem(address _erc721address, uint8 _status) public virtual onlyOwner {
        require(_erc721address != address(0));
        enable_tokens[_erc721address] = _status;
        emit SetEnableItem(_erc721address, _status);
    }

    function getEnableItem(address _erc721address) public view virtual returns(uint8) {
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

    function setMinimumTxFee(uint8 _value) public onlyOwner {
        minimumTxFee = _value;
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
        uint256 _rand
    )
        nonReentrant
        onlyAgent
        external
        payable
        returns(uint256)
    {
        (, address _from) = checkProxyMint(_signature, _contract, _fee, _nonce, _rand);

        // 関数の実行前に、残っているGASの量を取得する
        uint256 gasStart = gasleft();

        // targetContractに外部関数呼び出しをする
        // fee支払い
        // _transfer(from, msg.sender, _fee); // fee支払い
        if (_fee > 0) {
            (bool success, ) = currency_token.call{value: msg.value}
                                    (abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", _from, msg.sender, _fee));
            require(success, "External function execution failed");
        }

        // 実行
        // require(IBlockSafari(_contract).externalMint(from));
        (bool success2, bytes memory res) = _contract.call{value: msg.value}
                                (abi.encodeWithSignature("mint(address)", _from));
        require(success2, "External function execution failed 2");
        uint256 tokenId = abi.decode(res, (uint256));

        signatures[_signature] = true;

        // 関数が使用したGASの量を計算する
        uint256 gasUsed = gasStart.sub(gasleft());

        // 未使用のETHを返還する
        uint256 refundAmount = msg.value.sub(gasUsed.mul(tx.gasprice));
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }
        emit ProxyMint(_contract, _from, tokenId, _fee, _nonce);
        return tokenId;
    }

    function checkProxyMint(
        bytes memory _signature,
        address _contract,
        uint256 _fee,
        uint256 _nonce,
        uint256 _rand
    )
        public
        view
        returns(bool, address)
    {
        require(isMintableContract(_contract) , "disabled token");
        require(signatures[_signature] == false, "used signature");
        bytes32 hashedTx = proxyMintPreSignedHashing(_contract, _fee, _nonce, _rand);
        address _from = ECDSAUpgradeable.recover(hashedTx, _signature);
        require(_from != address(0), "invalid signature");
        require(IERC20Upgradeable(currency_token).balanceOf(_from) >= _fee, "lack of funds");
        require(_fee >= minimumTxFee, "minimum Tx Fee");

        return (true, _from);
    }

    function isMintableContract(address _contract) public view returns(bool) {
        if (enable_tokens[_contract] > 0) {
            return true;
        } else {
            return false;
        }
    }

    function proxyMintPreSignedHashing(
        address _contract,
        uint256 _fee,
        uint256 _nonce,
        uint256 _rand
    )
        internal
        pure
        returns (bytes32)
    {
        /* "0x92fac361": proxyMintPreSignedHashing(address,uint256,uint256,uint256) */
        return keccak256(abi.encodePacked(bytes4(0x92fac361), _contract, _fee, _nonce, _rand));
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
        onlyAgent
        external
        payable
        returns(bool)
    {
        (, address _parentOwner1, address _parentOwner2) = checkProxyCrossbreed(_contract, _parent1, _parent2);

        // 関数の実行前に、残っているGASの量を取得する
        uint256 gasStart = gasleft();

        _payCrossbreedFees(_parentOwner1, _parentOwner2, _parent1.fee, _parent2.fee);

        uint256 tokenId1 = _crossbreedMint(_contract, _parentOwner1);
        _afterProcess(_contract, tokenId1, _parent1.parentTokenId, _parent1.partnerTokenId);

        uint256 tokenId2 = _crossbreedMint(_contract, _parentOwner2);
        _afterProcess(_contract, tokenId2, _parent2.parentTokenId, _parent2.partnerTokenId);

        signatures[_parent1.signature] = true;
        signatures[_parent2.signature] = true;

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
        CrossbreedSeed memory _parent1,
        CrossbreedSeed memory _parent2
    )
        isCrossbreedable(_contract, _parent1, _parent2)
        public
        view
        returns(bool, address, address)
    {
        require(isCrossbreedableContract(_contract), "disabled token");
        require(_parent1.parentTokenId != _parent2.parentTokenId);
        require(_parent1.parentTokenId == _parent2.partnerTokenId && _parent2.parentTokenId == _parent1.partnerTokenId, "invalid transaction");
        require(_parent1.fee.add(_parent2.fee) >= minimumTxFee, "minimum Tx Fee");

        address _parentOwner1 = _authCrossbreed(_contract, _parent1);
        address _parentOwner2 = _authCrossbreed(_contract, _parent2);
        return (true, _parentOwner1, _parentOwner2);
    }

    modifier isCrossbreedable(address _contract, CrossbreedSeed memory _seed1, CrossbreedSeed memory _seed2) {
        require(isCrossbreedLocked(_contract, _seed1.parentTokenId));
        require(isCrossbreedLocked(_contract, _seed2.parentTokenId));
        require(!isFamily(_contract, _seed1.parentTokenId, _seed2.parentTokenId));
        _;
    }

    function isCrossbreedableContract(address _contract) public view returns(bool) {
        if (enable_tokens[_contract] == 2) {
            return true;
        } else {
            return false;
        }
    }

    function isFamily(address _contract, uint256 _tokenId, uint256 _targetId) public view virtual returns(bool) {
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

    function isCrossbreedLocked(address _contract, uint256 _tokenId) public view virtual returns(bool) {
        if (block.timestamp > crossbreedLock[_contract][_tokenId]) {
            return true;
        } else {
            return false;
        }
    }

    function _payCrossbreedFees(address _parentOwner1, address _parentOwner2, uint256 _fee1, uint256 _fee2) internal {
        // targetContractに外部関数呼び出しをする
        // fee支払い
        // _transfer(from, msg.sender, _fee); // fee支払い
        (bool success, ) = currency_token.call{value: msg.value}
                                (abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", _parentOwner1, msg.sender, _fee1));
        require(success, "External function execution failed 1");
        (success, ) = currency_token.call{value: msg.value}
                                (abi.encodeWithSignature("externalTransferFrom(address,address,uint256)", _parentOwner2, msg.sender, _fee2));
        require(success, "External function execution failed 2");
    }

    function _crossbreedMint(address _contract, address _parentOwner) internal returns(uint256) {
        // 実行
        // require(IBlockSafari(_contract).externalMint(from, _tokenId));
        (bool success, bytes memory res) = _contract.call{value: msg.value}
                                (abi.encodeWithSignature("safeMint(address)", _parentOwner));
        require(success, "External function execution failed 3");
        uint256 tokenId = abi.decode(res, (uint256));
        return tokenId;
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
        /* "0x361c4ee6": proxyMintPreSignedHashing(address,uint256,uint256,uint256,uint256) */
        return keccak256(abi.encodePacked(bytes4(0x361c4ee6), _contract, _seed.parentTokenId, _seed.partnerTokenId, _seed.fee, _seed.nonce));
    }

    function _afterProcess(address _contract, uint256 _tokenId, uint256 _parentTokenId, uint256 _partnerTokenId) internal
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

    function updateCrossbreedLockDays(uint8 _days) public onlyOwner {
        crossbreedLockDays = _days;
    }

    function updateMinimumTaxFee(uint256 _fee) public onlyOwner {
        minimumTxFee = _fee;
    }

    function balanceOf(address _from) public view returns(uint256) {
        return IERC20Upgradeable(currency_token).balanceOf(_from);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}