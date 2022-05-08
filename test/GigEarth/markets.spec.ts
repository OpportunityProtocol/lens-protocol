// We import Chai to use its asserting functions here.
import { expect } from 'chai'
import { ContractReceipt, BigNumber, Event, Signer, Wallet, BigNumberish } from 'ethers';
import {ethers} from 'hardhat'
import { TestDai } from '../../typechain-types/TestDai'
import { SimpleCentralizedArbitrator } from '../../typechain-types/SimpleCentralizedArbitrator'
import { waitForTx, initEnv, getAddrs, ZERO_ADDRESS } from '../../tasks/helpers/utils';
import { getContractFactory } from '@nomiclabs/hardhat-ethers/types';
import '@nomiclabs/hardhat-ethers';
import { adminAccount, baseCost, domainNoSubdomainNameVerifier, employer, hatchTokens, ideaTokenFactory, makeSuiteCleanRoom, moduleGlobals, platformFeeRate, priceRise, tradingFeeRate, worker, workerAddress, zeroAddress } from '../__setup.spec';

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

describe("Markets", async function () {
  let marketDeployer

  const FLATE_RATE_CONTRACT_INIT_DATA = { escrow: '0', valuePtr: '0', _taskMetadataPtr: '8dj39Dks8' }
  const MILESTONE_CONTRACT_INIT_DATA = { escrow: '0', valuePtr: '0', taskMetadataPtr: '8js82kd0f', numMilstones: 5}

  makeSuiteCleanRoom('Markets', function () {
    beforeEach(async function () {
    
      const generalAddrs = await ethers.getSigners()
      marketDeployer = generalAddrs[0]

      //create worker profile
      const workerProfileData : CreateProfileDataStruct = {
        to: workerAddress,
        handle: 'randomworker',
        imageURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
        followModule: relationshipFollowModule.address,
        followModuleInitData: [],
        followNFTURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
      }

      const employerNonce = await employer.getTransactionCount()
      const employerDeadline = Date.now().toString()
      const post = await getPostWithSigParts('randomworker', 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan', zeroAddress, [], zeroAddress, [], employerNonce, employerDeadline)

      gigEarth.connect(worker).registerWorker(workerProfileData);

      //create market
      const marketName = 'Writing and Translation'
      ideaTokenFactory.connect(adminAccount).addMarket(
				marketName,
				domainNoSubdomainNameVerifier.address,
				baseCost,
				priceRise,
			  hatchTokens,
				tradingFeeRate,
				platformFeeRate,
				false
			)

      //create service
      const marketID = await ideaTokenFactory.getMarketIDByName(marketName)
      const postServiceEIP712SignatureStruct: EIP712SignatureStruct = {
        v: post.v,
        r: post.r,
        s: post.s,
        deadline: employerDeadline
      }
      const postWithSig : PostWithSigDataStruct = {
        profileId: 'randomworker',
        contentURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
        collectModule: zeroAddress,
        collectModuleInitData: [],
        referenceModule: zeroAddress,
        referenceModuleInitData: [],
        sig: postServiceEIP712SignatureStruct
      };

      gigEarth.connect(worker).createService(
        marketID, 
        'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan', 
        100, 
        10,
        10,
        postServiceEIP712SignatureStruct)

      const tokenID = ideaTokenFactory.connect(adminAccount).getTokenIDByName("Name", marketID)
      console.log("The token id is: " + tokenID)

      // Set default values for contracts to deploy
      /*FLATE_RATE_CONTRACT_INIT_DATA.escrow = '0'
      FLATE_RATE_CONTRACT_INIT_DATA.valuePtr = testDaiInstance.address
  
      MILESTONE_CONTRACT_INIT_DATA.escrow = FLATE_RATE_CONTRACT_INIT_DATA.escrow
      MILESTONE_CONTRACT_INIT_DATA.valuePtr = FLATE_RATE_CONTRACT_INIT_DATA.valuePtr
  
      // mint test dai to employer and worker
      await testDaiInstance.mint(employer.address, 1000)
      await testDaiInstance.mint(worker.address, 1000)
  
      expect(await testDaiInstance.balanceOf(employer.address)).to.equal(BigNumber.from(1000))
      expect(await testDaiInstance.balanceOf(worker.address)).to.equal(BigNumber.from(1000))

      const employerProfileData : CreateProfileDataStruct = {
        to: employer.address,
        handle: 'randomemployer',
        imageURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
        followModule: relationshipFollowModule.address,
        followModuleData: [],
        followNFTURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
      }

      const workerProfileData : CreateProfileDataStruct = {
        to: worker.address,
        handle: 'randomworker',
        imageURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
        followModule: relationshipFollowModule.address,
        followModuleData: [],
        followNFTURI: 'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
      }

      await expect(gigEarth.connect(employer).register(employerProfileData)).to.not.be.reverted;
      await expect(gigEarth.connect(worker).register(workerProfileData)).to.not.to.reverted;

      
      const employerProfileId = await lensHub.getProfileIdByHandle(employerProfileData.handle);
      const workerProfileId = await lensHub.getProfileIdByHandle(workerProfileData.handle);*/
     /*
      const employerNonce = await employer.getTransactionCount()
      console.log('EMPLOYER NONCE: ' + employerNonce)
      const today = new Date()
      const tomorrow = new Date(today)
      tomorrow.setDate(tomorrow.getDate() + 1)
      console.log("OWNER: " + await lensHub.ownerOf(BigNumber.from(employerProfileId)))
      console.log('EMPLOYER ADDR: ' + employer.address)
      console.log('GIG EARTH ADDR: '  + gigEarth.address)
      const deadlineOne =  Math.trunc((tomorrow.getTime() + 120 * 1000) / 1000).toString()
      const employerSig = await getSetDispatcherWithSigParts(BigNumber.from(employerProfileId), gigEarth.address, employerNonce, deadlineOne)
      const SET_EMPLOYER_DISPATCHER_DATA : SetDispatcherWithSigDataStruct = {
        profileId: employerProfileId,
        dispatcher: gigEarth.address,
        sig: {
          v: employerSig.v,
          r: employerSig.r,
          s: employerSig.s,
          deadline: deadlineOne
        }
      }
      console.log(employerSig)*/

     // await expect(gigEarth.connect(employer).setGigEarthDispatcher(SET_EMPLOYER_DISPATCHER_DATA)).to.not.be.reverted
      /*await expect(gigEarth.connect(employer).toggleAutomatedActions(true)).to.not.be.reverted;

 

      const workerNonce = await worker.getTransactionCount()
      const deadlineTwo =  Math.trunc((Date.now() + 120 * 1000) / 1000).toString()
      const workerSig = await getSetDispatcherWithSigParts(BigNumber.from(workerProfileId), gigEarth.address, workerNonce, deadlineTwo)
      const SET_WORKER_DISPATCHER_DATA : SetDispatcherWithSigDataStruct = {
        profileId: workerProfileId,
        dispatcher: gigEarth.address,
        sig: {
          v: workerSig.v,
          r: workerSig.r,
          s: workerSig.s,
          deadline: deadlineTwo
        }
      }
      
      await expect(gigEarth.connect(worker).setGigEarthDispatcher(SET_WORKER_DISPATCHER_DATA)).to.not.be.reverted;
      await expect(gigEarth.connect(worker).toggleAutomatedActions(true)).to.not.be.reverted;

      console.log('Completed?')*/


    });

   context('GigEarth', function() {
      it("happy path - flat rate relationship - employer should create relationship and successfully complete with a worker", async () => {

       /* const marketDeploymentTx = await gigEarth
          .connect(marketDeployer)
          .createMarket(
            "Test Market One", 
            testDaiInstance.address
          )

          console.log(marketDeploymentTx)
  
         const marketDeploymentTxReceipt = await marketDeploymentTx.wait()
          const marketDeploymentTxEvents = marketDeploymentTxReceipt.events?.find(event => event.event == 'MarketCreated')
          const deployedMarketAddress = marketDeploymentTxEvents?.args?.[0]
            
          console.log('Create relationship')
          await gigEarth.connect(employer).createFlatRateRelationship(1, "sdas", BigNumber.from(new Date().getSeconds()))

          console.log('about to grant')
  
          await gigEarth.connect(employer).grantProposalRequest(1, worker.address, testDaiInstance.address, 1000, "")
            
          console.log('about to approve')
          await testDaiInstance.connect(employer).approve(gigEarth.address, 1000);
          console.log('@@@@@@@@')
            

          await gigEarth.connect(worker).work(BigNumber.from(1), "@8vj30_df")
          console.log('resolve trad')

          await gigEarth.connect(worker).submitWork(1, '@hDJ83^*~')
          await gigEarth.connect(employer).resolveTraditional(1, 20)
            console.log('resolved')
          expect(await testDaiInstance.balanceOf(employer.address)).to.equal(BigNumber.from(0))
          expect(await testDaiInstance.balanceOf(worker.address)).to.equal(BigNumber.from(2000))
          console.log('balance works out')*/
      })
    })
  })
});