// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import './Ownable.sol';
import './Initializable.sol';
import '../interface/IInterestManager.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {IAToken} from '@aave/core-v3/contracts/interfaces/IAToken.sol';
import 'hardhat/console.sol';

/**
 * @title InterestManagerAave
 * @author Alexander Schlindwein
 *
 * Invests DAI into Compound to generate interest
 * Sits behind an AdminUpgradabilityProxy
 */
contract InterestManagerAave is Ownable, Initializable {
    using SafeMath for uint256;

    // Dai contract
    IERC20 internal _dai;
    // aDai contract
    IAToken internal _aDai;
    //Llending pool contract
    IPool internal _pool;

    /**
     * Initializes the contract with all required values
     *
     * @param owner The owner of the contract
     * @param dai The Dai token address
     * @param aDai The aDai token address
     * @param pool The aave lending pool token address
     */
    function initialize(
        address owner,
        address dai,
        address aDai,
        address pool
    ) external virtual initializer {
        require(dai != address(0) && aDai != address(0) && pool != address(0), 'invalid-params');

        setOwnerInternal(owner); // Checks owner to be non-zero
        _dai = IERC20(dai);
        _aDai = IAToken(aDai);
        _pool = IPool(pool);
    }

    /**
     * Invests a given amount of Dai into Aave
     * The Dai have to be transfered to this contract before this function is called
     *
     * @param amount The amount of Dai to invest
     *
     * @return The amount of minted cDai
     */
    function invest(uint256 amount) external virtual onlyOwner returns (uint256) {
        uint256 aDaiBalanceBefore = _aDai.balanceOf(address(this));
        uint256 daiBalanceBefore = _dai.balanceOf(address(this));

        require(_dai.balanceOf(address(this)) >= amount, 'insufficient-dai');
        require(_dai.approve(address(_pool), amount), 'dai-aavepool-approve');
        _pool.supply(address(_dai), amount, address(this), 0);

        uint256 aDaiBalanceAfter = _aDai.balanceOf(address(this));
        uint256 daiBalanceAfter = _dai.balanceOf(address(this));

        return aDaiBalanceAfter.sub(aDaiBalanceBefore);
    }

    /**
     * Redeems a given amount of Dai from Aave and sends it to the recipient
     *
     * @param recipient The recipient of the redeemed Dai
     * @param amount The amount of Dai to redeem
     *
     * @return The amount of burned cDai
     */
    function redeem(address recipient, uint256 amount)
        external
        virtual
        onlyOwner
        returns (uint256)
    {
        uint256 balanceBefore = _aDai.balanceOf(address(this));

        _pool.withdraw(address(_dai), amount, address(this));
        uint256 balanceAfter = _aDai.balanceOf(address(this));

        require(_dai.transfer(recipient, amount), 'dai-transfer');
        return balanceAfter;
    }

    /**
     * Redeems a given amount of cDai from Compound and sends Dai to the recipient
     *
     * @param recipient The recipient of the redeemed Dai
     * @param amount The amount of cDai to redeem
     *
     * @return The amount of redeemed Dai
     */
    function redeemInvestmentToken(address recipient, uint256 amount)
        external
        virtual
        onlyOwner
        returns (uint256)
    {
        uint256 balanceBefore = _aDai.balanceOf(address(this));
        _pool.withdraw(address(_dai), amount, recipient);
        uint256 balanceAfter = _aDai.balanceOf(address(this));
        require(_dai.transfer(recipient, amount), 'dai-transfer');
        return balanceAfter;
    }

    /**
     * Converts an amount of underlying tokens to an amount of investment tokens
     *
     * @param underlyingAmount The amount of underlying tokens
     *
     * @return The amount of investment tokens
     */
    function underlyingToInvestmentToken(uint256 underlyingAmount)
        external
        view
        virtual
        returns (uint256)
    {
        return underlyingAmount;
    }

    /**
     * Converts an amount of investment tokens to an amount of underlying tokens
     *
     * @param investmentTokenAmount The amount of investment tokens
     *
     * @return The amount of underlying tokens
     */
    function investmentTokenToUnderlying(uint256 investmentTokenAmount)
        external
        view
        virtual
        returns (uint256)
    {
        return investmentTokenAmount;
    }
}
