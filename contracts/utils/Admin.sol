// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract Admin is OwnableUpgradeable {

    /**
     * 管理権限
     * 0 => admin: ゲームの管理アカウント
     * 1 => agent: APIからトークンのmintなどtx発行の代行が可能
     */
    mapping(uint256 => mapping(address => bool)) internal admin;

    /**
     * admin
     */
    modifier onlyAdmin(uint8 number) {
        require(admin[number][msg.sender] == true || owner() == msg.sender, "caller is not the owner");
        _;
    }

    function addAdmin(uint8 number, address member) public virtual onlyOwner {
        require(member != address(0), "new admin member is the zero address");
        admin[number][member] = true;
    }

    function removeAdmin(uint8 number, address member) public virtual onlyOwner {
        require(member != address(0), "admin member is the zero address");
        admin[number][member] = false;
    }
}
