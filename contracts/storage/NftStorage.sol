// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../utils/Admin.sol";

contract NftStorage is Initializable,Admin {

    mapping(address => bool) internal trusted;

    string internal uri;
}