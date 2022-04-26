// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
contract UserSummary is ERC1155 {
    constructor(string memory lensProfileContentUri) ERC1155(lensProfileContentUri) {}
}