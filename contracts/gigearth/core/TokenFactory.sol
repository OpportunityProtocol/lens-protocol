// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "../proxy/MinimalProxy.sol";
import "../util/Initializable.sol";
import "../util/Ownable.sol";
import "../interface/ITokenFactory.sol";
import "./ServiceToken.sol";
import "../interface/IServiceToken.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";
import "../interface/INetworkManager.sol";
/**
 * @title TokenFactory (Original: IdeaTokenFactory)
 * @author Elijah Hampton (Original: Alexander Schlindwein)
 *
 * Manages the creation of markets and ServiceTokens
 * Sits behind an AdminUpgradabilityProxy
 */
contract TokenFactory is ITokenFactory, Initializable, Ownable {

    using SafeMath for uint256;

    // Contains details for each market
    struct MarketInfo {
        mapping(uint => TokenInfo) tokens;
        mapping(string => uint) tokenIDs;
        mapping(string => bool) tokenNameUsed;
    }

    uint constant FEE_SCALE = 10000;

    // Address of the IdeaTokenExchange contract
    // This is needed to transfer ownership of a newly created IdeaToken to the IdeaTokenExchange
    address _tokenExchange;

    // Address of the IdeaToken logic contract
    address _tokenLogic; //Investigage

    // ServiceTokenAddress => IDPair. Stores an IDPair (marketID, tokenID) for a ServiceToken
    mapping(address => IDPair) _tokenIDPairs;

    // marketID => MarketInfo. Stores information for a market
    mapping(uint => MarketInfo) _markets;
    // market name => marketID. Translates market names to market IDs.
    mapping(string => uint) _marketIDs;
    // The amount of existing markets.
    uint _numMarkets;

        mapping(address => uint) _tokenAddressToMarketID;

    //marketID => MarketDetails 
    mapping(uint => MarketDetails) _marketDetails;

    mapping (string => MarketInfo) _marketInfo;
 
    address _networkManager;

    event NewMarket(uint id,
                    string name,
                    uint baseCost,
                    uint priceRise,
                    uint hatchTokens,
                    uint tradingFeeRate,
                    uint platformFeeRate,
                    bool allInterestToPlatform);

    event NewToken(uint id, uint marketID, string name, address addr, address lister);
    event NewTradingFee(uint marketID, uint tradingFeeRate);
    event NewPlatformFee(uint marketID, uint platformFeeRate);

    modifier onlyNetworkManager() {
        require(msg.sender == _networkManager, "sender is not network manager");
        _;
    }

    /**
     * Initializes the contract with all required values
     *
     * @param owner The owner of the contract (Should be network manager)
     */
    function initialize(address owner, address tokenExchange, address tokenLogic, address networkManager) external virtual initializer {
        require(tokenExchange != address(0) && tokenLogic != address(0), "invalid-params");

        setOwnerInternal(owner); // Checks owner to be non-zero
        _tokenExchange = tokenExchange;
        _tokenLogic = tokenLogic;
        _networkManager = networkManager;
    }

    /**
     * Adds a new market
     * May only be called by the owner
     *
     * @param marketName The name of the market
     * @param baseCost: The initial cost in Dai per IdeaToken in the first interval
     * @param priceRise: The price rise in Dai per IdeaToken per completed interval
     * @param hatchTokens: The amount of IdeaTokens for which the price does not change initially
     * @param tradingFeeRate: The trading fee rate
     * @param platformFeeRate: The platform fee rate
     * @param allInterestToPlatform: If true, all interest goes to the platform instead of the token owner
     */
    function addMarket(string calldata marketName,
                       uint baseCost, uint priceRise, uint hatchTokens,
                       uint tradingFeeRate, uint platformFeeRate, bool allInterestToPlatform) external virtual override returns(uint256) {

        require(_marketIDs[marketName] == 0, "market-exists");

        require(baseCost > 0 &&
                tradingFeeRate.add(platformFeeRate) <= FEE_SCALE,
                "invalid-params");

        uint marketID = ++_numMarkets;

        MarketInfo storage info = _marketInfo[marketName];

        _marketDetails[marketID] = MarketDetails({
                exists: true,
                id: marketID,
                name: marketName,
                numTokens: 0,
                baseCost: baseCost,
                priceRise: priceRise,
                hatchTokens: hatchTokens,
                tradingFeeRate: tradingFeeRate,
                platformFeeRate: platformFeeRate,
                allInterestToPlatform: allInterestToPlatform
        });

        _marketIDs[marketName] = marketID;
        emitNewMarketEvent(_marketDetails[marketID]);
        return marketID;
    }

    /// Stack too deep if we do it directly in `addMarket`
    function emitNewMarketEvent(MarketDetails memory marketDetails) internal virtual {
        emit NewMarket(marketDetails.id,
                       marketDetails.name,
                       marketDetails.baseCost,
                       marketDetails.priceRise,
                       marketDetails.hatchTokens,
                       marketDetails.tradingFeeRate,
                       marketDetails.platformFeeRate,
                       marketDetails.allInterestToPlatform);
    }

    /**
     * Adds a new ServiceToken using MinimalProxy
     *
     * @param tokenName The name of the token
     * @param marketID The ID of the market
     * @param lister The address of the account which off-chain software shall see as lister of this token. Only emitted, not stored
     */
    function addToken(string calldata tokenName, uint marketID, address lister) external virtual override onlyNetworkManager returns(uint) {
        MarketInfo storage marketInfo = _markets[marketID];
        require(_marketDetails[marketID].exists, "market-not-exist");
       // require(isValidTokenName(tokenName, marketID), "invalid-name");

        IServiceToken serviceToken = IServiceToken(address(new MinimalProxy(_tokenLogic)));

        _tokenAddressToMarketID[address(serviceToken)] = marketID;

        serviceToken.initialize(string(abi.encodePacked( _marketDetails[marketID].name, ": ", tokenName)), _tokenExchange);

        uint tokenID = ++_marketDetails[marketID].numTokens;
        TokenInfo memory tokenInfo = TokenInfo({
            exists: true,
            id: tokenID,
            name: tokenName,
            serviceToken: serviceToken
        });

        marketInfo.tokens[tokenID] = tokenInfo;
        marketInfo.tokenIDs[tokenName] = tokenID;
        marketInfo.tokenNameUsed[tokenName] = true;
        _tokenIDPairs[address(serviceToken)] = IDPair({
            exists: true,
            marketID: marketID,
            tokenID: tokenID
        });

        emit NewToken(tokenID, marketID, tokenName, address(serviceToken), lister);
        return tokenID;
    }

    /**
     * Checks whether a token name is allowed and not used already
     *
     * @param tokenName The intended token name
     * @param marketID The market on which the token is to be listed
     *
     * @return True if the name is allowed, false otherwise
     */
    function isValidTokenName(string calldata tokenName, uint marketID) public virtual view override returns (bool) {

        MarketInfo storage marketInfo = _markets[marketID];
        MarketDetails storage marketDetails =  _marketDetails[marketID];

        if(marketInfo.tokenNameUsed[tokenName]) {
            return false;
        }

        return true;
    }

    /**
     * Returns the market id by the market name
     *
     * @param marketName The market name
     *
     * @return The market id
     */
    function getMarketIDByName(string calldata marketName) external view override returns (uint) {
        return _marketIDs[marketName];
    }

    /**
     * Returns the market details by the market id
     *
     * @param marketID The market id
     *
     * @return The market details
     */
    function getMarketDetailsByID(uint marketID) external view override returns (MarketDetails memory) {
        return  _marketDetails[marketID];
    }

    /**
     * Returns the market details by the market name
     *
     * @param marketName The market name
     *
     * @return The market details
     */
    function getMarketDetailsByName(string calldata marketName) external view override returns (MarketDetails memory) {
        return  _marketDetails[0];
    }

    function getMarketDetailsByTokenAddress(address serviceToken) external view override returns (MarketDetails memory) {
        return _marketDetails[0];
    }

    /**
     * Returns the amount of existing markets
     *
     * @return The amount of existing markets
     */
    function getNumMarkets() external view override  returns (uint) {
        return _numMarkets;
    }

    /**
     * Returns the token id by the token name and market id
     *
     * @param tokenName The token name
     * @param marketID The market id
     *
     * @return The token id
     */
    function getTokenIDByName(string calldata tokenName, uint marketID) external view override returns (uint) {
        return _markets[marketID].tokenIDs[tokenName];
    }

    /**
     * Returns the token info by the token id and market id
     *
     * @param marketID The market id
     * @param tokenID The token id
     *
     * @return The token info
     */
    function getTokenInfo(uint marketID, uint tokenID) external view override returns (TokenInfo memory) {
        return _markets[marketID].tokens[tokenID];
    }

    /**
     * Returns the token id pair by the tokens address
     *
     * @param token The tokens address
     *
     * @return The token id pair
     */
    function getTokenIDPair(address token) external view override returns (IDPair memory) {
        return _tokenIDPairs[token];
    }

    /**
     * Sets the trading fee for a market
     * May only be called by the owner
     *
     * @param marketID The market id for which to set the trading fee
     * @param tradingFeeRate The trading fee
     */
    function setTradingFee(uint marketID, uint tradingFeeRate) external virtual override onlyOwner {
        MarketDetails storage marketDetails =  _marketDetails[marketID];
        require(marketDetails.exists, "market-not-exist");
        require(marketDetails.platformFeeRate.add(tradingFeeRate) <= FEE_SCALE, "invalid-fees");
        marketDetails.tradingFeeRate = tradingFeeRate;
        
        emit NewTradingFee(marketID, tradingFeeRate);
    }

    /**
     * Sets the platform fee for a market
     * May only be called by the owner
     *
     * @param marketID The market id for which to set the platform fee
     * @param platformFeeRate The platform fee
     */
    function setPlatformFee(uint marketID, uint platformFeeRate) external virtual override onlyOwner {
        MarketDetails storage marketDetails =  _marketDetails[marketID];
        require(marketDetails.exists, "market-not-exist");
        require(marketDetails.tradingFeeRate.add(platformFeeRate) <= FEE_SCALE, "invalid-fees");
        marketDetails.platformFeeRate = platformFeeRate;

        emit NewPlatformFee(marketID, platformFeeRate);
    }

    function getMarketIDByTokenAddress(address tokenAddress) external virtual view override returns(uint) {
        return _tokenAddressToMarketID[tokenAddress];
    }
}