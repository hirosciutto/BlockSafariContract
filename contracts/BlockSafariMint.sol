// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./storage/MintStorage.sol";

/**
 * Proxy Contract
 */
contract BlockSafariMint is ERC1967Proxy, MintStorage {

    /*
    * init function
    */
    constructor(
        address _logic,
        bytes memory _data
    )
    ERC1967Proxy(_logic,_data)
    {
        _transferOwnership(msg.sender);
    }

    /**
     * 呼び出しアドレスの取得
     */
    function implementation() public view returns(address) {
        return _implementation();
    }
}