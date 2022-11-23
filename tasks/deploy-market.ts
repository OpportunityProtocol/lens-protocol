//lens-talent-local-startup-util
import { task } from 'hardhat/config';
import {
  InterestManagerAave__factory,
  LensHub__factory,
  ModuleGlobals__factory,
  NetworkManager__factory,
  ServiceToken__factory,
  TestDai__factory,
  TokenExchange__factory,
  TokenFactory__factory,
} from '../typechain-types';
import { deployContract, waitForTx } from './helpers/utils';
import { BigNumber, Contract, Signer } from 'ethers';

import fs from 'fs';
import {
  polygonMumbaiAaveDaiAddress,
  aavePolygonMumbaiPool,
  lensHubMumbaiGovernance,
  lensHubMumbaiProfileCreationProxyAddress,
  lensHubPolygonMumbaiAddress,
  lensMumbaiModuleGlobalPolygonMumbaiAddress,
  polygonMumbaiDaiAddress,
  DAI_ABI,
} from './constants';

const tenPow18 = BigNumber.from('1000000000000000000');
const zeroAddress = '0x0000000000000000000000000000000000000000';
const oneAddress = '0x0000000000000000000000000000000000000001';
const twoAddress = '0x0000000000000000000000000000000000000002';
const baseCost = BigNumber.from('100000000000000000'); // 10**17 = $0.1
const priceRise = BigNumber.from('100000000000000'); // 10**14 = $0.0001
const hatchTokens = BigNumber.from('1000000000000000000000'); // 10**21 = 1000
const tradingFeeRate = BigNumber.from('100');
const platformFeeRate = BigNumber.from('50');

task(
  'deploy-market',
  'deploys lens talent'
).setAction(async ({ }, hre) => {
 // hre.ethers.provider = new hre.ethers.providers.JsonRpcProvider(hre.ethers.provider.connection.url)
  hre.run('compile')

  const ethers = hre.ethers;
  const signers = await ethers.getSigners();
  const deployer = signers[0];
  const admin: Signer = await ethers.getSigner('0xFaD20fD4eC620BbcA8091eF5DC04b73dc0e2868a');

    const tokenFactory = TokenFactory__factory.connect('0xa75af6f336142a2f70feB77a3b20Af7dFFbD9Ce6', admin)
  //add markets
  await waitForTx(
    tokenFactory.addMarket(
      'Software Development',
      baseCost,
      priceRise,
      hatchTokens,
      tradingFeeRate,
      platformFeeRate,
      false
    )
  );


});
