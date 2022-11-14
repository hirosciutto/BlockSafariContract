// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Ownable.sol";

abstract contract Admin is Ownable {

    /**
     * admin
     */
    modifier onlyAdmin() {
        require(_admin[0][msg.sender] == true || _owner == msg.sender, "caller is not the owner");
        _;
    }

    function addAdmin(address member) public virtual onlyOwner {
        require(member != address(0), "new admin member is the zero address");
        _admin[0][member] = true;
    }

    function removeAdmin(address member) public virtual onlyOwner {
        require(member != address(0), "admin member is the zero address");
        _admin[0][member] = false;
    }

    /**
     * agent
     */
    modifier onlyAgent() {
        require(_admin[1][msg.sender] == true || _owner == msg.sender, "caller is not the owner");
        _;
    }

    function addAgent(address member) public virtual onlyAdmin {
        require(newMember != address(0), "new agent member is the zero address");
        _admin[1][member] = true;
    }

    function removeAgent(address member) public virtual onlyAdmin {
        require(newMember != address(0), "agent member is the zero address");
        _admin[1][member] = false;
    }

}
