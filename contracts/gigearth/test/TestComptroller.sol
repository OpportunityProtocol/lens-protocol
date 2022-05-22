// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IComptroller.sol";

/**
 * @title TestComptroller
 * @author Alexander Schlindwein
 *
 * @dev Comptroller for testing
 */
contract TestComptroller is IComptroller {
    /**
     * @dev Claims COMP for a holder. Disabled for tests
     *
     * @param holder The address to claim the COMP for
     */
    function claimComp(address holder) external override {
        holder;
    }
}
