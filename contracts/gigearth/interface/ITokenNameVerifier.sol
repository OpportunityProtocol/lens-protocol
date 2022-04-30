// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title IIdeaTokenNameVerifier
 * @author Alexander Schlindwein
 *
 * Interface for token name verifiers
 */
interface ITokenNameVerifier {
    function verifyTokenName(string calldata name) external pure returns (bool);
}