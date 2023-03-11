// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./MarketStorage.sol";

/**
 * Proxy Contract
 */
contract BlockSafariMarket is ERC1967Proxy, MarketStorage {

    /*
    * init function
    */
    constructor(
        address _logic,
        bytes memory _data
    )
    ERC1967Proxy(_logic,_data)
    {
        __Ownable_init();
        admin[0][msg.sender] = true;
    }

    /**
     * 呼び出しアドレスの取得
     */
    function implementation() public returns(address) {}
}