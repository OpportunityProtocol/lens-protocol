// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IIdeaToken
 * @author Alexander Schlindwein
 */
interface IServiceToken is IERC20 {
    function initialize(string calldata __name, address owner) external;
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
}