// We import Chai to use its asserting functions here.
import { expect } from 'chai'
import { ContractReceipt, BigNumber, Event, Signer, Wallet, BigNumberish } from 'ethers';
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

describe("Users", async function () {

  makeSuiteCleanRoom('Users', function () {
    beforeEach(async function () {
      await dai.mint(workerAddress, tenPow18.mul(BigNumber.from('1000000000000000000000')))
      await dai.mint(employer.address, tenPow18.mul(BigNumber.from('1000000000000000000000')))
      await dai.mint(testWallet.address, tenPow18.mul(BigNumber.from('1000000000000000000000')))

      await dai.connect(worker).approve(ideaTokenExchange.address, tenPow18.mul(BigNumber.from('1000000000000000000000')))
      await dai.connect(testWallet).approve(ideaTokenExchange.address, tenPow18.mul(BigNumber.from('1000000000000000000000')))
    });

    context('Users', function () {
      it("user should be able to register as a worker and create a profile through lens protocol", async () => {
        //create worker profile
        const testWorkerProfileData:  CreateProfileDataStruct = {
          to: await gigEarth.address,
          handle: "testworkerhandle",
          imageURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
          followModule: zeroAddress,
          followModuleInitData: [],
          followNFTURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
        }

        await expect(gigEarth.connect(worker).registerWorker(testWorkerProfileData)).to.not.be.reverted;
        const workerProfileId = await lensHub.getProfileIdByHandle('testworkerhandle')

        await expect(lensHub.getProfileIdByHandle('testworkerhandle')).to.equal(workerProfileId)
      })

            //TODO: Add to next test case
            it("user should be able to deposit service creation payout in escrow", async () => {

            })
      
            it("user should be able to create a service", async () => {
              //create worker profile
              const testWorkerProfileData:  CreateProfileDataStruct = {
                to: await gigEarth.address,
                handle: "testworkerhandle",
                imageURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
                followModule: zeroAddress,
                followModuleInitData: [],
                followNFTURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
              }
      
              await gigEarth.connect(worker).registerWorker(testWorkerProfileData)
      
              //create market
              const testMarketName = 'TEST_MARKET'
      
              await ideaTokenFactory.connect(adminAccount).addMarket(
                testMarketName,
                baseCost,
                priceRise,
                hatchTokens,
                tradingFeeRate,
                platformFeeRate,
                false
              );
      
              //create service
              const workerProfileId = await lensHub.getProfileIdByHandle('testWorkerHandle')
              const marketID = await (await ideaTokenFactory.getMarketIDByName(testMarketName))._hex
              const details = await (await ideaTokenFactory.getMarketDetailsByID(marketID)).name
              const workerNonce = await (await lensHub.sigNonces(await worker.getAddress())).toNumber()
              const workerDeadline = MAX_UINT256
      
              await lensHub.connect(governance).whitelistCollectModule(zeroAddress, true);
      
              const post = await getPostWithSigParts(workerProfileId, 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan', zeroAddress, [], zeroAddress, [], workerNonce, workerDeadline)
              const postServiceEIP712SignatureStruct: EIP712SignatureStruct = {
                v: post.v,
                r: post.r,
                s: post.s,
                deadline: workerDeadline
              }
      
              await gigEarth.connect(worker).createService(
                marketID,
                'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
                100,
                10,
                10,
                postServiceEIP712SignatureStruct)
            })
      
            it("user should be able to purchase service and settle service", async () => {
              const testWorkerProfileData: CreateProfileDataStruct = {
                to: await gigEarth.address,
                handle: "testworkerhandle",
                imageURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
                followModule: zeroAddress,
                followModuleInitData: [],
                followNFTURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
              }
      
              await gigEarth.connect(worker).registerWorker(testWorkerProfileData)
      
              //create market
              const testMarketName = 'TEST_MARKET'
      
              await ideaTokenFactory.connect(adminAccount).addMarket(
                testMarketName,
                baseCost,
                priceRise,
                hatchTokens,
                tradingFeeRate,
                platformFeeRate,
                false
              );
      
              //create service
              const workerProfileId = await lensHub.getProfileIdByHandle('testWorkerHandle')
              const marketID = await (await ideaTokenFactory.getMarketIDByName(testMarketName))._hex
              const details = await (await ideaTokenFactory.getMarketDetailsByID(marketID)).name
              const workerNonce = await (await lensHub.sigNonces(await worker.getAddress())).toNumber()
              const workerDeadline = MAX_UINT256
      
              await lensHub.connect(governance).whitelistCollectModule(zeroAddress, true);
      
              const post = await getPostWithSigParts(workerProfileId, 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan', zeroAddress, [], zeroAddress, [], workerNonce, workerDeadline)
              const postServiceEIP712SignatureStruct:  EIP712SignatureStruct = {
                v: post.v,
                r: post.r,
                s: post.s,
                deadline: workerDeadline
              }
      
              const createServiceTx = await gigEarth.connect(worker).createService(
                marketID,
                'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
                100,
                10,
                10,
                postServiceEIP712SignatureStruct
                )

              await createServiceTx.wait()
      
              await gigEarth.connect(employer).purchaseServiceOffering(1, zeroAddress);
              await gigEarth.connect(employer).resolveService(1, 1);
                

                let serviceData;
                serviceData = await gigEarth.getServiceData(1);
                
                const protocolFee = await gigEarth.getProtocolFee();
                const workerBalance = await dai.balanceOf(worker.address)
                const expectedBalanceAfterResolution = serviceData.wad * 50
                
                expect(workerBalance).equals(expectedBalanceAfterResolution)
            })
      
            it("user should be able to buy and sell service tokens after settling service", async () => {
      
            })
      
            it("user should be able to purchase and settle contract", async () => {
              const testWorkerProfileData:  CreateProfileDataStruct = {
                to: await gigEarth.address,
                handle: "testworkerhandle",
                imageURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
                followModule: zeroAddress,
                followModuleInitData: [],
                followNFTURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
              }
      
              await gigEarth.connect(worker).registerWorker(testWorkerProfileData)
      
              //create market
              const testMarketName: string = 'TEST_MARKET'
      
              await ideaTokenFactory.connect(adminAccount).addMarket(
                testMarketName,
                baseCost,
                priceRise,
                hatchTokens,
                tradingFeeRate,
                platformFeeRate,
                false
              );
      
              await gigEarth.connect(employer).createContract(1, "9dsj93n2r")
              await gigEarth.connect(employer).grantProposalRequest(1, worker.address, 2000);
              await gigEarth.connect(employer).resolveContract(1, "jd3jfsfaf")
      
              const contractData = await gigEarth.getServiceData(1);
              const protocolFee = await gigEarth.getProtocolFee();
              const workerBalance = await dai.balanceOf(worker.address)
              const expectedBalanceAfterResolution = 2000 * 50;
              expect(workerBalance).equals(expectedBalanceAfterResolution)
            })
    })
  })
});