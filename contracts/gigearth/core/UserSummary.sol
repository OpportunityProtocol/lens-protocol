// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract UserSummary is ERC20 {
    constructor(string memory lensProfileContentUri) ERC20(lensProfileContentUri, _generateRandomSymbol()) {}

    function _generateRandomSymbol() internal returns(string memory) {
        return "";
    }
}