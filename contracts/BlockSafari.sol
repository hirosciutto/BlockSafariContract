// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "./utils/Ownable.sol";

contract BlockSarari is Ownable,Proxy {

    /*
    * init function
    */
    function initialize(
        address logic_contract_address_,
        string name_,
        string symbol_,
        string uri_
    ) public initializer {
        _uri = uri_;

        _owner = msg.sender;
        _admin[0][msg.sender] = true;

        // ロジックコントラクトをセット
        logic_contract = logic_contract_address_;

        // name,symbol設定
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * 呼び出しアドレスの取得
     */
    function _implementation() external override returns(address) {
        return logic_contract;
    }

    /**
     * ロジックコントラクトの更新
     */
    function updateTo(address contract_address) external returns(address) onlyOwner {
        require(contract_address != address(0));
        logic_contract = contract_address;
    }
}