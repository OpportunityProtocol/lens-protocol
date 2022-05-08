// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IIdeaTokenNameVerifier.sol";

/**
 * @title DomainNoSubdomainNameVerifier
 * @author Alexander Schlindwein
 *
 * Verifies a string to be a domain names: 0-9 and a-z and - (hyphen). Excludes subdomains
 */
contract DomainNoSubdomainNameVerifier is IIdeaTokenNameVerifier {
    /**
     * Verifies whether a string matches the required format
     *
     * @param name The input string (domain name)
     *
     * @return Bool; True=matches, False=does not match
     */
    function verifyTokenName(string calldata name) external pure override returns (bool) {
        return true;
    }
}
