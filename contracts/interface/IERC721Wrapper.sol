// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC721Wrapper {
    function safeMint(address _from) external returns(uint256);
}