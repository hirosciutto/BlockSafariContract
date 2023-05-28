// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract Admin is OwnableUpgradeable {

    /**
     * プロキシ可能な非中央集権的コントラクトの管理をオーナー配下のアカウントによって管理可能にするためのコントラクト
     */
    mapping(address => bool) internal admin;

    mapping(address => bool) internal agent;

    modifier onlyAdmin() {
        require(admin[msg.sender] == true || owner() == msg.sender, "caller is not the owner");
        _;
    }

    function addAdmin(address _account) public virtual onlyOwner {
        require(_account != address(0), "new admin member is the zero address");
        admin[_account] = true;
    }

    function removeAdmin(address _account) public virtual onlyOwner {
        require(_account != address(0), "admin member is the zero address");
        admin[_account] = false;
    }

    function addAgent(address _account) public virtual onlyAdmin {
        require(_account != address(0), "new admin member is the zero address");
        agent[_account] = true;
    }

    function removeAgent(address _account) public virtual onlyAdmin {
        require(_account != address(0), "admin member is the zero address");
        agent[_account] = false;
    }
}
