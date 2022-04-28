// SPDX-License-Identifier: MIT
pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

/**
 * @title ITokenVault (Original: IIdeaTokenVault)
 * @author Elijah Hampton (Original: Alexander Schlindwein)
 */

struct LockedEntry {
    uint lockedUntil;
    uint lockedAmount;
}
    
interface ITokenVault {
    function lock(address serviceToken, uint amount, uint duration, address recipient) external;
    function withdraw(address serviceToken, uint[] calldata untils, address recipient) external;
    function getLockedEntries(address serviceToken, address user, uint maxEntries) external view returns (LockedEntry[] memory);
} 