// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IServiceToken.sol";

/**
 * @title ITokenFactory
 * @author Alexander Schlindwein
 */

struct IDPair {
    bool exists;
    uint marketID;
    uint tokenID;
}

struct TokenInfo {
    bool exists;
    uint id;
    string name;
    IServiceToken serviceToken;
}

struct MarketDetails {
    bool exists;
    uint id;
    string name;

    uint numTokens;

    uint baseCost;
    uint priceRise;
    uint hatchTokens;
    uint tradingFeeRate;
    uint platformFeeRate;

    bool allInterestToPlatform;
}

interface ITokenFactory {
    function addMarket(string calldata marketName,
                       uint baseCost, uint priceRise, uint hatchTokens,
                       uint tradingFeeRate, uint platformFeeRate, bool allInterestToPlatform) external returns(uint);

    function addToken(string calldata tokenName, uint marketID, address lister) external returns(uint);

    function getMarketIDByName(string calldata marketName) external view returns (uint);
    function getMarketDetailsByID(uint marketID) external view returns (MarketDetails memory);
    function getMarketDetailsByName(string calldata marketName) external view returns (MarketDetails memory);
    function getMarketDetailsByTokenAddress(address serviceToken) external view returns (MarketDetails memory);
    function getNumMarkets() external view returns (uint);
    function getTokenIDByName(string calldata tokenName, uint marketID) external view returns (uint);
    function getTokenInfo(uint marketID, uint tokenID) external view returns (TokenInfo memory);
    function getTokenIDPair(address token) external view returns (IDPair memory);
    function setTradingFee(uint marketID, uint tradingFeeRate) external;
    function setPlatformFee(uint marketID, uint platformFeeRate) external;
    function getMarketIDByTokenAddress(address tokenAddress) external view returns(uint);
}