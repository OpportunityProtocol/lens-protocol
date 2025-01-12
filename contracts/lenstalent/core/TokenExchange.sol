// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import '../util/Ownable.sol';
import '../util/Initializable.sol';

import '../interface/ITokenExchange.sol';
import '../interface/IServiceToken.sol';
import '../interface/ITokenFactory.sol';
import '../interface/IInterestManager.sol';

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

import 'hardhat/console.sol';

interface INetworkManager {
    function isFamiliarWithService(address employer, uint256 serviceId) external returns (bool);
}

/**
 * @title TokenExchange
 *
 * Exchanges Dai <-> ServiceTokens using a bonding curve. Sits behind a proxy
 */
contract TokenExchange is ITokenExchange, Initializable, Ownable {
    using SafeMath for uint256;

    // Stored for every ServiceToken and market.
    // Keeps track of the amount of invested dai in this token, and the amount of investment tokens (e.g. cDai).
    struct ExchangeInfo {
        // The amount of Dai collected by trading
        uint256 dai;
        // The amount of "investment tokens", e.g. cDai
        uint256 invested;
        // The id of the specific token invested
        uint256 id;
    }

    uint256 constant FEE_SCALE = 10000;

    // The address authorized to set token and platform owners.
    // It is only allowed to change these when the current owner is not set (zero address).
    // Using such an address allows an external program to make authorization calls
    address _authorizer;

    // The amount of "investment tokens" for the collected trading fee, e.g. cDai
    uint256 _tradingFeeInvested;
    // The address which receives the trading fee when withdrawTradingFee is called
    address _tradingFeeRecipient;

    // marketID => owner. The owner of a platform.
    // This address is allowed to withdraw platform fee.
    // When allInterestToPlatform=true then this address can also withdraw the platform interest
    mapping(uint256 => address) _platformOwner;

    // marketID => amount. The amount of "investment tokens" for the collected platform fee, e.g. cDai
    mapping(uint256 => uint256) _platformFeeInvested;

    // marketID => ExchangeInfo. Stores ExchangeInfo structs for platforms
    mapping(uint256 => ExchangeInfo) _platformsExchangeInfo;

    // ServiceToken address => owner. The owner of an ServiceToken.
    // This address is allowed to withdraw the interest for an ServiceToken
    mapping(address => address) _tokenOwner;
    // ServiceToken address => ExchangeInfo. Stores ExchangeInfo structs for ServiceTokens
    mapping(address => ExchangeInfo) _tokensExchangeInfo;

    // TokenFactory contract
    ITokenFactory _tokenFactory;
    // InterestManager contract
    IInterestManager _interestManager;
    // Dai contract
    IERC20 _dai;
    //Network Manager
    INetworkManager _networkManager;

    // ServiceToken address => bool. Whether or not to disable all fee collection for a specific ServiceToken.
    mapping(address => bool) _tokenFeeKillswitch;

    event NewTokenOwner(address serviceToken, address owner);
    event NewPlatformOwner(uint256 marketID, address owner);

    event InvestedState(
        uint256 marketID,
        address serviceToken,
        uint256 dai,
        uint256 daiInvested,
        uint256 tradingFeeInvested,
        uint256 platformFeeInvested,
        uint256 volume
    );

    event PlatformInterestRedeemed(uint256 marketID, uint256 investmentToken, uint256 daiRedeemed);
    event TokenInterestRedeemed(address serviceToken, uint256 investmentToken, uint256 daiRedeemed);
    event TradingFeeRedeemed(uint256 daiRedeemed);
    event PlatformFeeRedeemed(uint256 marketID, uint256 daiRedeemed);

    /**
     * Initializes the contract
     *
     * @param owner The owner of the contract
     * @param tradingFeeRecipient The address of the recipient of the trading fee
     * @param interestManager The address of the InterestManager
     * @param dai The address of Dai
     */
    function initialize(
        address owner,
        address authorizer,
        address tradingFeeRecipient,
        address tokenFactory,
        address interestManager,
        address dai
    ) external virtual initializer {
        require(
            authorizer != address(0) &&
                tradingFeeRecipient != address(0) &&
                interestManager != address(0) &&
                dai != address(0) &&
                tokenFactory != address(0),
            'invalid-params'
        );

        setOwnerInternal(owner); // Checks owner to be non-zero
        _authorizer = authorizer;
        _tradingFeeRecipient = tradingFeeRecipient;
        _tokenFactory = ITokenFactory(tokenFactory);
        _interestManager = IInterestManager(interestManager);
        _dai = IERC20(dai);
    }

    /**
     * Burns ServiceTokens in exchange for Dai
     *
     * @param serviceToken The ServiceToken to sell
     * @param amount The amount of ServiceTokens to sell
     * @param minPrice The minimum allowed price in Dai for selling `amount` ServiceTokens
     * @param recipient The recipient of the redeemed Dai
     */
    function sellTokens(
        address serviceToken,
        uint256 amount,
        uint256 minPrice,
        address recipient
    ) external virtual override {
        uint256 marketID = _tokenFactory.getMarketIDByTokenAddress(serviceToken);
        MarketDetails memory marketDetails = _tokenFactory.getMarketDetailsByID((marketID));

        require(marketDetails.exists, 'token-not-exist');

        CostAndPriceAmounts memory amounts = getPricesForSellingTokens(
            marketDetails,
            IERC20(serviceToken).totalSupply(),
            amount,
            _tokenFeeKillswitch[serviceToken]
        );

        require(amounts.total >= minPrice, 'below-min-price');
        require(IServiceToken(serviceToken).balanceOf(msg.sender) >= amount, 'insufficient-tokens');
        IServiceToken(serviceToken).burn(msg.sender, amount);

        ExchangeInfo storage exchangeInfo;
        if (marketDetails.allInterestToPlatform) {
            exchangeInfo = _platformsExchangeInfo[marketID];
        } else {
            exchangeInfo = _tokensExchangeInfo[serviceToken];
        }

        uint256 tradingFeeInvested;
        uint256 platformFeeInvested;
        uint256 invested;
        uint256 dai;
        {
            uint256 totalRedeemed = 100; //_interestManager.redeem(address(this), amounts.total);
            uint256 tradingFeeRedeemed = 0; /*_interestManager.underlyingToInvestmentToken(
                amounts.tradingFee
            );*/
            uint256 platformFeeRedeemed = 0; /*_interestManager.underlyingToInvestmentToken(
                amounts.platformFee
            );*/
            invested = exchangeInfo.invested.sub(
                totalRedeemed.add(tradingFeeRedeemed).add(platformFeeRedeemed)
            );
            exchangeInfo.invested = invested;
            tradingFeeInvested = _tradingFeeInvested.add(tradingFeeRedeemed);
            _tradingFeeInvested = tradingFeeInvested;
            platformFeeInvested = _platformFeeInvested[marketID].add(platformFeeRedeemed);
            _platformFeeInvested[marketID] = platformFeeInvested;
            dai = exchangeInfo.dai.sub(amounts.raw);
            exchangeInfo.dai = dai;
        }

        emit InvestedState(
            marketID,
            serviceToken,
            dai,
            invested,
            tradingFeeInvested,
            platformFeeInvested,
            amounts.raw
        );
        //require(_dai.transfer(recipient, amounts.total), 'dai-transfer');
    }

    /**
     * Calculates each price related to selling tokens
     *
     * @param marketDetails The market details
     * @param supply The existing supply of the ServiceToken
     * @param amount The amount of ServiceTokens to sell
     *
     * @return total cost, raw cost and trading fee
     */
    function getPricesForSellingTokens(
        MarketDetails memory marketDetails,
        uint256 supply,
        uint256 amount,
        bool feesDisabled
    ) public pure virtual override returns (CostAndPriceAmounts memory) {
        uint256 rawPrice = getRawPriceForSellingTokens(
            marketDetails.baseCost,
            marketDetails.priceRise,
            marketDetails.hatchTokens,
            supply,
            amount
        );

        uint256 tradingFee = 0;
        uint256 platformFee = 0;

        if (!feesDisabled) {
            tradingFee = rawPrice.mul(marketDetails.tradingFeeRate).div(FEE_SCALE);
            platformFee = rawPrice.mul(marketDetails.platformFeeRate).div(FEE_SCALE);
        }

        uint256 totalPrice = rawPrice.sub(tradingFee).sub(platformFee);

        return
            CostAndPriceAmounts({
                total: totalPrice,
                raw: rawPrice,
                tradingFee: tradingFee,
                platformFee: platformFee
            });
    }

    /**
     * Returns the price for selling tokens without any fees applied
     *
     * @param baseCost The baseCost of the token
     * @param priceRise The priceRise of the token
     * @param hatchTokens The amount of hatch tokens
     * @param supply The current total supply of the token
     * @param amount The amount of ServiceTokens to sell
     *
     * @return The price selling `amount` ServiceTokens without any fees applied
     */
    function getRawPriceForSellingTokens(
        uint256 baseCost,
        uint256 priceRise,
        uint256 hatchTokens,
        uint256 supply,
        uint256 amount
    ) internal pure virtual returns (uint256) {
        uint256 hatchPrice = 0;
        uint256 updatedAmount = amount;
        uint256 updatedSupply;

        if (supply.sub(amount) < hatchTokens) {
            if (supply <= hatchTokens) {
                return baseCost.mul(amount).div(10**18);
            }

            // No SafeMath required because supply - amount < hatchTokens
            uint256 tokensInHatch = hatchTokens - (supply - amount);
            hatchPrice = baseCost.mul(tokensInHatch).div(10**18);
            updatedAmount = amount.sub(tokensInHatch);
            // No SafeMath required because supply >= hatchTokens
            updatedSupply = supply - hatchTokens;
        } else {
            // No SafeMath required because supply >= hatchTokens
            updatedSupply = supply - hatchTokens;
        }

        uint256 priceAtSupply = baseCost.add(priceRise.mul(updatedSupply).div(10**18));
        uint256 priceAtSupplyMinusAmount = baseCost.add(
            priceRise.mul(updatedSupply.sub(updatedAmount)).div(10**18)
        );
        uint256 average = priceAtSupply.add(priceAtSupplyMinusAmount).div(2);

        return hatchPrice.add(average.mul(updatedAmount).div(10**18));
    }

    /**
     * Mints ServiceTokens in exchange for Dai
     *
     * @param serviceToken The ServiceToken to buy
     * @param amount The amount of ServiceTokens to buy
     * @param fallbackAmount The fallback amount to buy in case the price changed
     * @param cost The maximum allowed cost in Dai
     * @param recipient The recipient of the bought ServiceTokens
     */
    function buyTokens(
        address serviceToken,
        uint256 amount,
        uint256 fallbackAmount,
        uint256 cost,
        address recipient
    ) external virtual override {
        IDPair memory tokenIDPair = _tokenFactory.getTokenIDPair(serviceToken);
        MarketDetails memory marketDetails = _tokenFactory.getMarketDetailsByID(
            (tokenIDPair.marketID)
        );

        require(marketDetails.exists, 'token-not-exist');

        uint256 supply = IERC20(serviceToken).totalSupply();
        bool feesDisabled = _tokenFeeKillswitch[serviceToken];
        uint256 actualAmount = amount;

        CostAndPriceAmounts memory amounts = getCostsForBuyingTokens(
            marketDetails,
            supply,
            actualAmount,
            feesDisabled
        );

        if (amounts.total > cost) {
            actualAmount = fallbackAmount;
            amounts = getCostsForBuyingTokens(marketDetails, supply, actualAmount, feesDisabled);

            require(amounts.total <= cost, 'slippage');
        }

        require(
            _dai.allowance(msg.sender, address(this)) >= amounts.total,
            'insufficient-allowance'
        );
        
        require(
            _dai.transferFrom(msg.sender, address(_interestManager), amounts.total),
            'dai-transfer'
        );

      //  _interestManager.invest(amounts.total);

        ExchangeInfo storage exchangeInfo;
        if (marketDetails.allInterestToPlatform) {
            exchangeInfo = _platformsExchangeInfo[tokenIDPair.marketID];
        } else {
            exchangeInfo = _tokensExchangeInfo[serviceToken];
        }

        exchangeInfo.invested = exchangeInfo.invested.add(
            _interestManager.underlyingToInvestmentToken(amounts.raw)
        );

        uint256 tradingFeeInvested = _tradingFeeInvested.add(
            _interestManager.underlyingToInvestmentToken(amounts.tradingFee)
        );
        _tradingFeeInvested = tradingFeeInvested;

        uint256 platformFeeInvested = _platformFeeInvested[tokenIDPair.marketID].add(
            _interestManager.underlyingToInvestmentToken(amounts.platformFee)
        );

        _platformFeeInvested[tokenIDPair.marketID] = platformFeeInvested;
        exchangeInfo.dai = exchangeInfo.dai.add(amounts.raw);

        emit InvestedState(
            tokenIDPair.marketID,
            serviceToken,
            exchangeInfo.dai,
            exchangeInfo.invested,
            tradingFeeInvested,
            platformFeeInvested,
            amounts.total
        );

        IServiceToken(serviceToken).mint(recipient, actualAmount);
    }

    /**
     * Returns the cost for buying ServiceTokens
     *
     * @param serviceToken The ServiceToken to buy
     * @param amount The amount of ServiceTokens to buy
     *
     * @return The cost in Dai for buying `amount` ServiceTokens
     */
    function getCostForBuyingTokens(address serviceToken, uint256 amount)
        external
        view
        virtual
        override
        returns (uint256)
    {
        uint256 marketID = _tokenFactory.getMarketIDByTokenAddress(serviceToken);

        MarketDetails memory marketDetails = _tokenFactory.getMarketDetailsByID(marketID);

        return
            getCostsForBuyingTokens(
                marketDetails,
                IERC20(serviceToken).totalSupply(),
                amount,
                _tokenFeeKillswitch[serviceToken]
            ).total;
    }

    /**
     * Calculates each cost related to buying tokens
     *
     * @param marketDetails The market details
     * @param supply The existing supply of the ServiceToken
     * @param amount The amount of ServiceTokens to buy
     *
     * @return total cost, raw cost, trading fee, platform fee
     */
    function getCostsForBuyingTokens(
        MarketDetails memory marketDetails,
        uint256 supply,
        uint256 amount,
        bool feesDisabled
    ) public pure virtual override returns (CostAndPriceAmounts memory) {
        uint256 rawCost = getRawCostForBuyingTokens(
            marketDetails.baseCost,
            marketDetails.priceRise,
            marketDetails.hatchTokens,
            supply,
            amount
        );

        uint256 tradingFee = 0;
        uint256 platformFee = 0;

        if (!feesDisabled) {
            tradingFee = rawCost.mul(marketDetails.tradingFeeRate).div(FEE_SCALE);
            platformFee = rawCost.mul(marketDetails.platformFeeRate).div(FEE_SCALE);
        }

        uint256 totalCost = rawCost.add(tradingFee).add(platformFee);

        return
            CostAndPriceAmounts({
                total: totalCost,
                raw: rawCost,
                tradingFee: tradingFee,
                platformFee: platformFee
            });
    }

    /**
     * Returns the cost for buying tokens without any fees applied
     *
     * @param baseCost The baseCost of the token
     * @param priceRise The priceRise of the token
     * @param hatchTokens The amount of hatch tokens
     * @param supply The current total supply of the token
     * @param amount The amount of ServiceTokens to buy
     *
     * @return The cost buying `amount` ServiceTokens without any fees applied
     */
    function getRawCostForBuyingTokens(
        uint256 baseCost,
        uint256 priceRise,
        uint256 hatchTokens,
        uint256 supply,
        uint256 amount
    ) internal pure virtual returns (uint256) {
        uint256 hatchCost = 0;
        uint256 updatedAmount = amount;
        uint256 updatedSupply;

        if (supply < hatchTokens) {
            // No SafeMath required because supply < hatchTokens
            uint256 remainingHatchTokens = hatchTokens - supply;

            if (amount <= remainingHatchTokens) {
                return baseCost.mul(amount).div(10**18);
            }

            hatchCost = baseCost.mul(remainingHatchTokens).div(10**18);
            updatedSupply = 0;
            // No SafeMath required because remainingHatchTokens < amount
            updatedAmount = amount - remainingHatchTokens;
        } else {
            // No SafeMath required because supply >= hatchTokens
            updatedSupply = supply - hatchTokens;
        }

        uint256 priceAtSupply = baseCost.add(priceRise.mul(updatedSupply).div(10**18));
        uint256 priceAtSupplyPlusAmount = baseCost.add(
            priceRise.mul(updatedSupply.add(updatedAmount)).div(10**18)
        );
        uint256 average = priceAtSupply.add(priceAtSupplyPlusAmount).div(2);

        return hatchCost.add(average.mul(updatedAmount).div(10**18));
    }

    /**
     * Withdraws available interest for a publisher
     *
     * @param token The token from which the generated interest is to be withdrawn
     */
    function withdrawTokenInterest(address token) external virtual override {
        require(_tokenOwner[token] == msg.sender, 'not-authorized');

        uint256 interestPayable = getInterestPayable(token);
        if (interestPayable == 0) {
            return;
        }

        ExchangeInfo storage exchangeInfo = _tokensExchangeInfo[token];
        exchangeInfo.invested = exchangeInfo.invested.sub(
            _interestManager.redeem(msg.sender, interestPayable)
        );

        emit TokenInterestRedeemed(token, exchangeInfo.invested, interestPayable);
    }

    /**
     * Returns the interest available to be paid out for a token
     *
     * @param token The token from which the generated interest is to be withdrawn
     *
     * @return The interest available to be paid out
     */
    function getInterestPayable(address token) public view virtual override returns (uint256) {
        ExchangeInfo storage exchangeInfo = _tokensExchangeInfo[token];
        return
            _interestManager.investmentTokenToUnderlying(exchangeInfo.invested).sub(
                exchangeInfo.dai
            );
    }

    /**
     * Sets an address as owner of a token, allowing the address to withdraw interest
     *
     * @param token The token for which to authorize an address
     * @param owner The address to be set as owner
     */
    function setTokenOwner(address token, address owner) external virtual override {
        address sender = msg.sender;
        address current = _tokenOwner[token];

        require(
            (current == address(0) && (sender == _owner || sender == _authorizer)) ||
                (current != address(0) && (sender == _owner || sender == current)),
            'not-authorized'
        );

        _tokenOwner[token] = owner;

        emit NewTokenOwner(token, owner);
    }

    /**
     * Withdraws available interest for a platform
     *
     * @param marketID The market id from which the generated interest is to be withdrawn
     */
    function withdrawPlatformInterest(uint256 marketID) external virtual override {
        address sender = msg.sender;

        require(_platformOwner[marketID] == sender, 'not-authorized');

        uint256 platformInterestPayable = getPlatformInterestPayable(marketID);
        if (platformInterestPayable == 0) {
            return;
        }

        ExchangeInfo storage exchangeInfo = _platformsExchangeInfo[marketID];
        exchangeInfo.invested = exchangeInfo.invested.sub(
            _interestManager.redeem(sender, platformInterestPayable)
        );

        emit PlatformInterestRedeemed(marketID, exchangeInfo.invested, platformInterestPayable);
    }

    /**
     * Returns the interest available to be paid out for a platform
     *
     * @param marketID The market id from which the generated interest is to be withdrawn
     *
     * @return The interest available to be paid out
     */
    function getPlatformInterestPayable(uint256 marketID)
        public
        view
        virtual
        override
        returns (uint256)
    {
        ExchangeInfo storage exchangeInfo = _platformsExchangeInfo[marketID];
        return
            _interestManager.investmentTokenToUnderlying(exchangeInfo.invested).sub(
                exchangeInfo.dai
            );
    }

    /**
     * Withdraws available platform fee
     *
     * @param marketID The market from which the generated platform fee is to be withdrawn
     */
    function withdrawPlatformFee(uint256 marketID) external virtual override {
        address sender = msg.sender;

        require(_platformOwner[marketID] == sender, 'not-authorized');

        uint256 platformFeePayable = getPlatformFeePayable(marketID);
        if (platformFeePayable == 0) {
            return;
        }

        _platformFeeInvested[marketID] = 0;
        _interestManager.redeem(sender, platformFeePayable);

        emit PlatformFeeRedeemed(marketID, platformFeePayable);
    }

    /**
     * Returns the platform fee available to be paid out
     *
     * @param marketID The market from which the generated interest is to be withdrawn
     *
     * @return The platform fee available to be paid out
     */
    function getPlatformFeePayable(uint256 marketID)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _interestManager.investmentTokenToUnderlying(_platformFeeInvested[marketID]);
    }

    /**
     * Authorizes an address as owner of a platform/market, which is allowed to withdraw platform fee and platform interest
     *
     * @param marketID The market for which to authorize an address
     * @param owner The address to be authorized
     */
    function setPlatformOwner(uint256 marketID, address owner) external virtual override {
        address sender = msg.sender;
        address current = _platformOwner[marketID];

        require(
            (current == address(0) && (sender == _owner || sender == _authorizer)) ||
                (current != address(0) && (sender == _owner || sender == current)),
            'not-authorized'
        );

        _platformOwner[marketID] = owner;

        emit NewPlatformOwner(marketID, owner);
    }

    /**
     * Withdraws available trading fee
     */
    function withdrawTradingFee() external virtual override {
        uint256 invested = _tradingFeeInvested;
        if (invested == 0) {
            return;
        }

        _tradingFeeInvested = 0;
        uint256 redeem = _interestManager.investmentTokenToUnderlying(invested);
        _interestManager.redeem(_tradingFeeRecipient, redeem);

        emit TradingFeeRedeemed(redeem);
    }

    /**
     * Returns the trading fee available to be paid out
     *
     * @return The trading fee available to be paid out
     */
    function getTradingFeePayable() public view virtual override returns (uint256) {
        return _interestManager.investmentTokenToUnderlying(_tradingFeeInvested);
    }

    /**
     * Sets the authorizer address
     *
     * @param authorizer The new authorizer address
     */
    function setAuthorizer(address authorizer) external virtual override onlyOwner {
        require(authorizer != address(0), 'invalid-params');
        _authorizer = authorizer;
    }

    /**
     * Returns whether or not fees are disabled for a specific ServiceToken
     *
     * @param serviceToken The ServiceToken
     *
     * @return Whether or not fees are disabled for a specific ServiceToken
     */
    function isTokenFeeDisabled(address serviceToken)
        external
        view
        virtual
        override
        returns (bool)
    {
        return _tokenFeeKillswitch[serviceToken];
    }

    /**
     * Sets the fee killswitch for an ServiceToken
     *
     * @param serviceToken The ServiceToken
     * @param set Whether or not to enable the killswitch
     */
    function setTokenFeeKillswitch(address serviceToken, bool set)
        external
        virtual
        override
        onlyOwner
    {
        _tokenFeeKillswitch[serviceToken] = set;
    }

    /**
     * Sets the TokenFactory address. Only required once for deployment
     *
     * @param factory The address of the TokenFactory
     */
    function setTokenFactoryAddress(address factory) external virtual onlyOwner {
        require(address(_tokenFactory) == address(0));
        _tokenFactory = ITokenFactory(factory);
    }
}
