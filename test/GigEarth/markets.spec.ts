// We import Chai to use its asserting functions here.
import { expect } from 'chai'
import { ContractReceipt, BigNumber, Event, Signer, Wallet, BigNumberish } from 'ethers';
import { ethers } from 'hardhat'
import { TestDai } from '../../typechain-types/TestDai'
import { SimpleCentralizedArbitrator } from '../../typechain-types/SimpleCentralizedArbitrator'
import { waitForTx, initEnv, getAddrs, ZERO_ADDRESS } from '../../tasks/helpers/utils';
import { getContractFactory } from '@nomiclabs/hardhat-ethers/types';
import '@nomiclabs/hardhat-ethers';
import { adminAccount, baseCost, dai, employer, governance, governanceAddress, hatchTokens, ideaTokenExchange, ideaTokenFactory, makeSuiteCleanRoom, moduleGlobals, platformFeeRate, priceRise, tenPow18, testWallet, tradingFeeRate, worker, workerAddress, zeroAddress } from '../__setup.spec';

import {
  lensHub,
  gigEarth,
  gigEarthGovernance,
  gigEarthTreasury,
  simpleArbitrator,
  relationshipFollowModule,
  relationshipReferenceModule
} from '../__setup.spec'

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { getPostWithSigParts, getSetDispatcherWithSigParts } from '../helpers/utils';
import { CreateProfileDataStruct, SetDispatcherWithSigDataStruct, PostWithSigDataStruct, EIP712SignatureStruct } from '../../typechain-types/LensHub';
import { MAX_UINT256 } from '../helpers/constants';

describe("Markets", async function () {

  makeSuiteCleanRoom('Markets', function () {
    beforeEach(async function () {
      await dai.mint(workerAddress, tenPow18.mul(BigNumber.from('1000000000000000000000')))
      await dai.mint(employer.address, tenPow18.mul(BigNumber.from('1000000000000000000000')))
      await dai.mint(testWallet.address, tenPow18.mul(BigNumber.from('1000000000000000000000')))

      await dai.connect(worker).approve(ideaTokenExchange.address, tenPow18.mul(BigNumber.from('1000000000000000000000')))
      await dai.connect(testWallet).approve(ideaTokenExchange.address, tenPow18.mul(BigNumber.from('1000000000000000000000')))
    });

    context('Markets', function () {
      it("owner should be able to create a market", async () => {
        const testMarket = "TEST_MARKET"
        await expect(ideaTokenFactory.connect(adminAccount).addMarket(
          testMarket,
          baseCost,
          priceRise,
          hatchTokens,
          tradingFeeRate,
          platformFeeRate,
          false
        )).to.not.be.revertedWith('invalid-params');

        expect(BigNumber.from('1').eq(await ideaTokenFactory.getNumMarkets())).to.be.equal
        expect(BigNumber.from('1').eq(await ideaTokenFactory.getMarketIDByName(testMarket))).to.be.equal

        const marketDetailsByID = await ideaTokenFactory.getMarketDetailsByID(BigNumber.from('1'))

        expect(marketDetailsByID.exists).to.be.true
        expect(marketDetailsByID.id.eq(BigNumber.from('1'))).to.be.true
        expect(marketDetailsByID.name).to.be.equal(testMarket)
        expect(marketDetailsByID.numTokens.eq(BigNumber.from('0'))).to.be.true
        expect(marketDetailsByID.baseCost.eq(baseCost)).to.be.true
        expect(marketDetailsByID.priceRise.eq(priceRise)).to.be.true
        expect(marketDetailsByID.hatchTokens.eq(hatchTokens)).to.be.true
        expect(marketDetailsByID.tradingFeeRate.eq(tradingFeeRate)).to.be.true
        expect(marketDetailsByID.platformFeeRate.eq(platformFeeRate)).to.be.true
      })
    })
  })
});