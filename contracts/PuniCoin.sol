// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PuniCoin is ERC20("PuniCoin", "PUNI"), Ownable {

    // 信頼したコントラクト
    mapping(address => bool) trusted;

    constructor() {
        _transferOwnership(msg.sender);
        _mint(msg.sender, 500000000 * (10 ** decimals()));
    }

    modifier onlyTrusted() {
        require(trusted[msg.sender] == true, "untrusted");
        _;
    }

    /**
    * コントラクトを信頼
    */
    function trust(address _tokenAddress, bool _status) onlyOwner public {
        require(!trusted[_tokenAddress], "invalid operation");
        trusted[_tokenAddress] = _status;
    }

    /**
     * ホワイトリスト確認
     */
    function isTrusted(address _tokenAddress) public view returns(bool) {
        return trusted[_tokenAddress];
    }

    /**
     * 外部からの信頼できるtransferFrom
     */
    function externalTransferFrom(address _from, address _to, uint256 _value) onlyTrusted public {
        require(balanceOf(_from) >= _value, "lack of funds");
        _transfer(_from, _to, _value);
    }

    function burn(uint256 _value) public {
        _burn(msg.sender, _value);
    }

}