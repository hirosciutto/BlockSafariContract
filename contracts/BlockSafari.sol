// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./utils/Ownable.sol";

/**
 * Proxy Contract
 */
contract BlockSafari is ERC1967Proxy, Ownable {

    /*
    * init function
    */
    constructor(
        string name_,
        string symbol_,
        string uri_,
        address _logic,
        bytes memory _data
    )
    ERC1967Proxy(_logic,_data)
    public {
        _uri = uri_;

        _owner = msg.sender;
        _admin[0][msg.sender] = true;

        // name,symbol設定
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * 呼び出しアドレスの取得
     */
    function implementation() public override returns(address) {}
}