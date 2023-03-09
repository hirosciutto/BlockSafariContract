// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Ownable.sol";

abstract contract Admin is Ownable {

    /**
     * admin
     */
    modifier onlyAdmin(uint8 number) {
        require(_admin[number][msg.sender] == true || _owner == msg.sender, "caller is not the owner");
        _;
    }

    function addAdmin(uint8 number, address member) public virtual onlyOwner {
        require(member != address(0), "new admin member is the zero address");
        _admin[number][member] = true;
    }

    function removeAdmin(uint8 number, address member) public virtual onlyOwner {
        require(member != address(0), "admin member is the zero address");
        _admin[number][member] = false;
    }
}
