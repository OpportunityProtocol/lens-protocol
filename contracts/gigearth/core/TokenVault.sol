// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "../interface/ITokenVault.sol";
import "../interface/ITokenFactory.sol";
import "./Ownable.sol";
import "./Initializable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TokenVault (Original: IIdeaTokenVault)
 * @author Elijah Hampton (Original: Alexander Schlindwein)
 *
 * Locks IdeaTokens for a given duration
 * Sits behind an AdminUpgradabilityProxy
 *
 * This contract uses a doubly linked list to keep track of locked tokens and allow for iteration.
 * For each (IdeaToken, owner) combination a linked list is stored where new entries to the list are inserted at the head:
 * 
 * |-----------| --- next ---> |-----------|
 * |  LLEntry  |			   |  LLEntry  |  ---- > 
 * |-----------| <--- prev --- |-----------|
 *       |
 *       |
 *       |
 * _llHead[IdeaToken][owner]
 *
 * Each LLEntry has an 'until' field which is the timestamp when the tokens in this entry will be unlocked.
 * A (IdeaToken, owner, until) combination uniquely identifies a LLEntry. Thus the 'until' also often serves as an ID.
 *
 * Since (IdeaToken, owner, until) is unique, the storage location of each LLEntry is calculated as keccak256(abi.encode(serviceToken, owner, until)).
 *
 */
contract TokenVault is ITokenVault, Initializable {
    using SafeMath for uint256;

    // LinkedList Entry
    struct LLEntry {
        // Timestamp when unlocked. Also serves as ID
        uint until;
        // Amount of locked tokens
        uint amount;
        // Previous LLEntry
        bytes32 prev;
        // Next LLEntry
        bytes32 next;
    }

    ITokenFactory _tokenFactory;

    // IdeaToken address => owner address => storage location
    mapping(address => mapping(address => bytes32)) public _llHead;

    event Locked(address serviceToken, address owner, uint lockedAmount, uint lockedUntil, uint lockedDuration);

    /**
     * Initializes the contract
     *
     * @param tokenFactory The address of the IdeaTokenFactory contract
     */
    function initialize(address tokenFactory) external initializer {
        require(tokenFactory != address(0), "invalid-params");
        _tokenFactory = ITokenFactory(tokenFactory);
    }

    /**
     * Locks tokens for a given duration.
     * Allowed durations are set by the owner.
     *
     * @param serviceToken The ServiceToken to be locked
     * @param amount The amount of IdeaTokens to lock
     * @param duration The duration in seconds to lock the tokens
     * @param recipient The account which receives the locked tokens 
     */
    function lock(address serviceToken, uint amount, uint duration, address recipient) external override {
        require(duration > 0, "invalid-duration");
        require(_tokenFactory.getTokenIDPair(serviceToken).exists, "invalid-token");
        require(amount > 0, "invalid-amount");
        require(IERC20(serviceToken).allowance(msg.sender, address(this)) >= amount, "insufficient-allowance");
        require(IERC20(serviceToken).transferFrom(msg.sender, address(this), amount), "transfer-failed");

        uint lockedUntil = duration.add(block.timestamp);
        bytes32 location = getLLEntryStorageLocation(serviceToken, recipient, lockedUntil);

        LLEntry storage entry = getLLEntry(location);
        entry.amount = entry.amount.add(amount);

        // If an entry with this `until` does not already exist,
        // create a new one and add it the LL
        if(entry.until == 0) {
            entry.until = lockedUntil;
            entry.prev = bytes32(0);
            entry.next = _llHead[serviceToken][recipient];

            bytes32 currentHeadID = _llHead[serviceToken][recipient];
            if(currentHeadID != bytes32(0)) {
                // Set `prev` of the old head to the new entry
                LLEntry storage head = getLLEntry(currentHeadID);
                head.prev = location;
            } 

            _llHead[serviceToken][recipient] = location;
        }

        emit Locked(serviceToken, recipient, amount, lockedUntil, duration);
    }

    /**
     * Withdraws a given list of locked tokens
     *
     * @param serviceToken The IdeaToken to withdraw
     * @param untils List of timestamps until which tokens are locked
     * @param recipient The account which will receive the IdeaTokens
     */
    function withdraw(address serviceToken, uint[] calldata untils, address recipient) external override {

        uint ts = block.timestamp;
        uint total = 0;

        for(uint i = 0; i < untils.length; i++) {
            uint until = untils[i];
            require(ts > until, "too-early");

            bytes32 location = getLLEntryStorageLocation(serviceToken, msg.sender, until);
            LLEntry storage entry = getLLEntry(location);

            require(entry.until > 0, "invalid-until");
            total = total.add(entry.amount);

            if(entry.next != bytes32(0)) {
                // Set `prev` of the next entry
                LLEntry storage next = getLLEntry(entry.next);
                next.prev = entry.prev;
            }

            if(entry.prev != bytes32(0)) {
                // Set `next` of the prev entry
                LLEntry storage prev = getLLEntry(entry.prev);
                prev.next = entry.next;
            } else {
                // This was the first entry in the LL
                // Update the head to the next entry
                // If this was also the only entry in the list
                // head will be set to 0
                _llHead[serviceToken][msg.sender] = entry.next;
            }

            // Reset storage to 0, gas savings
            clearEntry(entry);
        }

        if(total > 0) {
            require(IERC20(serviceToken).transfer(recipient, total), "transfer-failed");
        }
    }

    /**
     * Returns all locked entries up to `maxEntries` for `user`
     *
     * @param serviceToken The IdeaToken for which to return the locked entries
     * @param user The user for which to return the locked entries
     * @param maxEntries The maximum amount of entries to return
     *
     * @return All locked entries up to `maxEntries` for `user`
     */
    function getLockedEntries(address serviceToken, address user, uint maxEntries) external view override returns (LockedEntry[] memory) {
        // Calculate the required size of the returned array
        bytes32 next = _llHead[serviceToken][user];
        uint len = 0;
        while(next != bytes32(0) && len < maxEntries) {
            len += 1;
            LLEntry storage entry = getLLEntry(next);
            next = entry.next;
        }

        if(len == 0) {
            LockedEntry[] memory empty;
            return empty;
        }

        LockedEntry[] memory ret = new LockedEntry[](len);

        uint index = 0;
        next = _llHead[serviceToken][user];
        while(next != bytes32(0)) {
            LLEntry storage entry = getLLEntry(next);
            
            ret[index] = LockedEntry({lockedUntil: entry.until, lockedAmount: entry.amount});

            index++;
            next = entry.next;
        }

        return ret;
    }

    function clearEntry(LLEntry storage entry) internal {
        entry.until = 0;
        entry.amount = 0;
        entry.prev = bytes32(0);
        entry.next = bytes32(0);
    }

    function getLLEntryStorageLocation(address serviceToken, address owner, uint until) internal pure returns (bytes32) {
        return keccak256(abi.encode(serviceToken, owner, until));
    }

    function getLLEntry(bytes32 location) internal pure returns (LLEntry storage) {
        LLEntry storage entry;
        assembly { entry.slot := location }
        return entry;
    } 
}