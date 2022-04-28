// SPDX-License-Identifier: MIT
pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import "./MinimalProxy.sol";
import "./Initializable.sol";
import "./Ownable.sol";
import "../interface/ITokenFactory.sol";
import "./ServiceToken.sol";
import "../interfaces/IServiceToken.sol";
import "./ITokenNameVerifier.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title ITokenFactory (Originally: IdeaTokenFactory)
 * @author Alexander Schlindwein
 *
 * Manages the creation of markets and IdeaTokens
 * Sits behind an AdminUpgradabilityProxy
 */
contract TokenFactory is ITokenFactory, Initializable, Ownable {

    using SafeMath for uint256;

    // Contains details for each market
    struct MarketInfo {
        mapping(uint => TokenInfo) tokens;
        mapping(string => uint) tokenIDs;
        mapping(string => bool) tokenNameUsed;

        MarketDetails marketDetails;
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

    event NewMarket(uint id,
                    string name,
                    uint baseCost,
                    uint priceRise,
                    uint hatchTokens,
                    uint tradingFeeRate,
                    uint platformFeeRate,
                    bool allInterestToPlatform,
                    address nameVerifier);

    event NewToken(uint id, uint marketID, string name, address addr, address lister);
    event NewTradingFee(uint marketID, uint tradingFeeRate);
    event NewPlatformFee(uint marketID, uint platformFeeRate);
    event NewNameVerifier(uint marketID, address nameVerifier);

    /**
     * Initializes the contract with all required values
     *
     * @param owner The owner of the contract (Should be network manager)
     */
    function initialize(address owner, address tokenExchange, address tokenLogic) external virtual initializer {
        require(tokenExchange != address(0) && tokenLogic != address(0), "invalid-params");

        setOwnerInternal(owner); // Checks owner to be non-zero
        _tokenExchange = ideaTokenExchange;
        _tokenLogic = ideaTokenLogic;
    }

    /**
     * Adds a new market
     * May only be called by the owner
     *
     * @param marketName The name of the market
     * @param nameVerifier The address of the name verifier
     * @param baseCost: The initial cost in Dai per IdeaToken in the first interval
     * @param priceRise: The price rise in Dai per IdeaToken per completed interval
     * @param hatchTokens: The amount of IdeaTokens for which the price does not change initially
     * @param tradingFeeRate: The trading fee rate
     * @param platformFeeRate: The platform fee rate
     * @param allInterestToPlatform: If true, all interest goes to the platform instead of the token owner
     */
    function addMarket(string calldata marketName, address nameVerifier,
                       uint baseCost, uint priceRise, uint hatchTokens,
                       uint tradingFeeRate, uint platformFeeRate, bool allInterestToPlatform) external virtual override onlyOwner {
        require(_marketIDs[marketName] == 0, "market-exists");

        require(nameVerifier != address(0) &&
                baseCost > 0 &&
                tradingFeeRate.add(platformFeeRate) <= FEE_SCALE,
                "invalid-params");

        uint marketID = ++_numMarkets;

        MarketInfo memory marketInfo = MarketInfo({
            marketDetails: MarketDetails({
                exists: true,
                id: marketID,
                name: marketName,
                nameVerifier: ITokenNameVerifier(nameVerifier),
                numTokens: 0,
                baseCost: baseCost,
                priceRise: priceRise,
                hatchTokens: hatchTokens,
                tradingFeeRate: tradingFeeRate,
                platformFeeRate: platformFeeRate,
                allInterestToPlatform: allInterestToPlatform
            })
        });

        _markets[marketID] = marketInfo;
        _marketIDs[marketName] = marketID;

        emitNewMarketEvent(marketInfo.marketDetails);
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
                       marketDetails.allInterestToPlatform,
                       address(marketDetails.nameVerifier));
    }

    /**
     * Adds a new ServiceToken using MinimalProxy
     *
     * @param serviceId The service this token represents
     * @param tokenName The name of the token
     * @param marketID The ID of the market
     * @param lister The address of the account which off-chain software shall see as lister of this token. Only emitted, not stored
     */
    function addToken(uint256 serviceId, string calldata tokenName, uint marketID, address lister) external virtual override {
        MarketInfo storage marketInfo = _markets[marketID];
        require(marketInfo.marketDetails.exists, "market-not-exist");
        require(isValidTokenName(tokenName, marketID), "invalid-name");

        IServiceToken serviceToken = IServiceToken(address(new MinimalProxy(_tokenLogic)));
        serviceToken.initialize(string(abi.encodePacked(marketInfo.marketDetails.name, ": ", tokenName)), _tokenExchange);

        uint tokenID = serviceId; //++marketInfo.marketDetails.numTokens;
        TokenInfo memory tokenInfo = TokenInfo({
            exists: true,
            id: tokenID,
            name: tokenName,
            ideaToken: serviceToken
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
        MarketDetails storage marketDetails = marketInfo.marketDetails;

        if(marketInfo.tokenNameUsed[tokenName] || !marketDetails.nameVerifier.verifyTokenName(tokenName)) {
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
        return _markets[marketID].marketDetails;
    }

    /**
     * Returns the market details by the market name
     *
     * @param marketName The market name
     *
     * @return The market details
     */
    function getMarketDetailsByName(string calldata marketName) external view override returns (MarketDetails memory) {
        return _markets[_marketIDs[marketName]].marketDetails;
    }

    function getMarketDetailsByTokenAddress(address serviceToken) external view override returns (MarketDetails memory) {
        return _markets[_tokenIDPairs[serviceToken].marketID].marketDetails;
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
        MarketDetails storage marketDetails = _markets[marketID].marketDetails;
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
        MarketDetails storage marketDetails = _markets[marketID].marketDetails;
        require(marketDetails.exists, "market-not-exist");
        require(marketDetails.tradingFeeRate.add(platformFeeRate) <= FEE_SCALE, "invalid-fees");
        marketDetails.platformFeeRate = platformFeeRate;

        emit NewPlatformFee(marketID, platformFeeRate);
    }

    /**
     * Changes the address of the name verifier for a market
     * May only be called by the owner
     *
     * @param marketID The marketID for which to change the name verifier
     * @param nameVerifier The new name verifier address
     */
    function setNameVerifier(uint marketID, address nameVerifier) external virtual override onlyOwner {
        require(nameVerifier != address(0), "zero-verifier");

        MarketDetails storage marketDetails = _markets[marketID].marketDetails;
        require(marketDetails.exists, "market-not-exist");
        marketDetails.nameVerifier = ITokenNameVerifier(nameVerifier);

        emit NewNameVerifier(marketID, nameVerifier);
    }
}