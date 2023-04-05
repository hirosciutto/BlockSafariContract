// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./MethodsStorage.sol";

/**
 * Proxy Contract
 */
contract BlockSafari is ERC1967Proxy, MethodsStorage {

    /*
    * init function
    */
    constructor(
        address _logic,
        bytes memory _data
    )
    ERC1967Proxy(_logic,_data)
    {
    }

    /**
     * 呼び出しアドレスの取得
     */
    function implementation() public view returns(address) {
        return _implementation();
    }
}