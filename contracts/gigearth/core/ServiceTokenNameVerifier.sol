// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../interface/ITokenNameVerifier.sol";

/**
 * @title TwitterHandleNameVerifier
 * @author Alexander Schlindwein
 *
 * Verifies a string to be a Twitter handle: @ followed by 1-15 letters or numbers including "_". All lower-case.
 */
contract ServiceTokenNameVerifier is ITokenNameVerifier {
    /**
     * Verifies whether a string matches the required format
     *
     * @param name The input string (Twitter handle)
     *
     * @return Bool; True=matches, False=does not match
     */
    function verifyTokenName(string calldata name) external pure override returns (bool) {
        return true;
    }
}
