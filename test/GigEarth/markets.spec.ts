// We import Chai to use its asserting functions here.
import { expect } from 'chai'
import { ContractReceipt, BigNumber, Event, Signer, Wallet } from 'ethers';
import {ethers} from 'hardhat'
import { TestDai } from '../../typechain-types/TestDai'
import { SimpleCentralizedArbitrator } from '../../typechain-types/SimpleCentralizedArbitrator'
import { waitForTx, initEnv, getAddrs, ZERO_ADDRESS } from '../../tasks/helpers/utils';
import { getContractFactory } from '@nomiclabs/hardhat-ethers/types';
import '@nomiclabs/hardhat-ethers';
import { makeSuiteCleanRoom, moduleGlobals } from '../__setup.spec';

import { lensHub } from '../__setup.spec'
import { GigEarth, GigEarthInterface, } from '../../typechain-types/GigEarth';

describe("Markets", async function () {
  let marketDeployer, employer, worker, governance, treasury

  let gigEarthInstance

  let TestDai
  let testDaiInstance : TestDai

  let arbitrator, gigEarth, referenceModule, followModule

  const FLATE_RATE_CONTRACT_INIT_DATA = { escrow: '0', valuePtr: '0', _taskMetadataPtr: '8dj39Dks8' }
  const MILESTONE_CONTRACT_INIT_DATA = { escrow: '0', valuePtr: '0', taskMetadataPtr: '8js82kd0f', numMilstones: 5}

  makeSuiteCleanRoom('Markets', function () {
    beforeEach(async function () {
    
      const generalAddrs = await ethers.getSigners()
      marketDeployer = generalAddrs[0]
      employer = generalAddrs[1]
      worker = generalAddrs[2]
      governance = generalAddrs[3]
      treasury = generalAddrs[4]

      arbitrator = "0x500D1d6A4c7D8Ae28240b47c8FCde034D827fD5e"
      gigEarth = "0xc4905364b78a742ccce7B890A89514061E47068D"
      referenceModule = "0x3521eF8AaB0323004A6dD8b03CE890F4Ea3A13f5"
      followModule = "0x7e35Eaf7e8FBd7887ad538D4A38Df5BbD073814a"

      gigEarthInstance = await ethers.getContractAt('GigEarth', gigEarth)

      TestDai = await ethers.getContractFactory("TestDai")
      testDaiInstance  = await TestDai.deploy(1)
  
      // Set default values for contracts to deploy
      FLATE_RATE_CONTRACT_INIT_DATA.escrow = '0'
      FLATE_RATE_CONTRACT_INIT_DATA.valuePtr = testDaiInstance.address
  
      MILESTONE_CONTRACT_INIT_DATA.escrow = FLATE_RATE_CONTRACT_INIT_DATA.escrow
      MILESTONE_CONTRACT_INIT_DATA.valuePtr = FLATE_RATE_CONTRACT_INIT_DATA.valuePtr
  
      // mint test dai to employer and worker
      await testDaiInstance.mint(employer.address, 1000)
      await testDaiInstance.mint(worker.address, 1000)
  
      expect(await testDaiInstance.balanceOf(employer.address)).to.equal(BigNumber.from(1000))
      expect(await testDaiInstance.balanceOf(worker.address)).to.equal(BigNumber.from(1000))

      const employerProfileData = {
        to: gigEarth.address,
        handle: 'randomemployer',
        imageURI: "",
        followModule: followModule,
        followModuleData: 0,
        followNFTURI: "",
      }

      const workerProfileData = {
        to: gigEarth.adderss,
        handle: 'randomworker',
        imageURI: "",
        followModule: followModule,
        followModuleData: 0,
        followNFTURI: "",
      }

      await gigEarthInstance.connect(employer).register(employerProfileData)
      await gigEarthInstance.connect(worker).register(workerProfileData)

      
      const employerProfileId = lensHub.getProfileIdByHandle(employerProfileData.handle);
      const SET_EMPLOYER_DISPATCHER_DATA = {
        profileId: employerProfileId,
        dispatcher: gigEarth.address,
        sig:
      }

      await gigEarthInstance.connect(employer).setGigEarthDispatcher(employerProfileId, gigEarth.address, SET_EMPLOYER_DISPATCHER_DATA)
      await gigEarthInstance.connect(employer).toggleAutomatedActions(true);

      const workerProfileId = lensHub.getProfileIdByHandle(workerProfileData.handle);
      const SET_WORKER_DISPATCHER_DATA = {
        profileId: workerProfileId,
        dispatcher: gigEarth.address,
        sig: 
      }
      await gigEarthInstance.connect(worker).setGigEarthDispatcher(workerProfileId, gigEarth.address, SET_WORKER_DISPATCHER_DATA)
      await gigEarthInstance.connect(worker).toggleAutomatedActions(true);


    });

    context('GigEarth', function() {
      it("happy path - flat rate relationship - employer should create relationship and successfully complete with a worker", async () => {
       /* console.log('deplyoign market')
        const marketDeploymentTx = await gigEarthInstance
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
          await gigEarthInstance
          .connect(employer)
          .createFlatRateRelationship(
            BigNumber.from(1), 
            FLATE_RATE_CONTRACT_INIT_DATA._taskMetadataPtr, 
            BigNumber.from(0)
          )

          console.log('about to grant')
  
          await gigEarthInstance.connect(employer).grantProposalRequest(1, worker.address, testDaiInstance.address, 1000, "")
            
          console.log('about to approve')
          await testDaiInstance.connect(employer).approve(gigEarthInstance.address, 1000);
            
          let LensEmployerToWorkerEIP712FollowData = {
            v: 0,
            r: 0,
            s: 0,
            deadline: 0
          }

          await gigEarthInstance.connect(worker).work(1, "")
  
          await gigEarthInstance.connect(employer).resolveTraditional(1, 20, LensEmployerToWorkerEIP712FollowData)
  
          expect(await testDaiInstance.balanceOf(employer.address)).to.equal(BigNumber.from(0))
          expect(await testDaiInstance.balanceOf(worker.address)).to.equal(BigNumber.from(2000))*/
      })
    })
  })




});