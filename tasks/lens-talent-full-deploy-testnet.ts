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
  'lens-talent-testnet-full-deploy',
  'deploys lens talent'
).setAction(async ({ }, hre) => {
 // hre.ethers.provider = new hre.ethers.providers.JsonRpcProvider(hre.ethers.provider.connection.url)
  hre.run('compile')

  const ethers = hre.ethers;
  const signers = await ethers.getSigners();
  const deployer = await ethers.getSigner('0xFaD20fD4eC620BbcA8091eF5DC04b73dc0e2868a'); //signers[0];
  const admin: Signer = await ethers.getSigner('0xFaD20fD4eC620BbcA8091eF5DC04b73dc0e2868a');

  const moduleGlobals = ModuleGlobals__factory.connect('0xcbCC5b9611d22d11403373432642Df9Ef7Dd81AD', admin)
  //const lensHub = LensHub__factory.connect(, admin)
  const dai = new Contract('0xD40282e050723Ae26Aeb0F77022dB14470f4e011'/*polygonMumbaiDaiAddress*/, DAI_ABI, admin);
  let deployerNonce = await ethers.provider.getTransactionCount(deployer.address);

  //DEPLOY CONTRACTS
  const interestManagerAave = await deployContract(
    new InterestManagerAave__factory(deployer).deploy({
      nonce: deployerNonce++,
    })
  );

  const tokenExchange = await deployContract(
    new TokenExchange__factory(deployer).deploy({
      nonce: deployerNonce++,
    })
  );

  const tokenFactory = await deployContract(
    new TokenFactory__factory(deployer).deploy({
      nonce: deployerNonce++,
    })
  );

  const tokenLogic = await deployContract(
    new ServiceToken__factory(deployer).deploy({
      nonce: deployerNonce++,
    })
  );

  const networkManager = await deployContract(
    new NetworkManager__factory(deployer).deploy({
      nonce: deployerNonce++,
    })
  );

  //INITIALIZE CONTRACTS
  await interestManagerAave
    .connect(deployer)
    .initialize(
      await admin.getAddress(),
      /*polygonMumbaiDaiAddress*/ '0xD40282e050723Ae26Aeb0F77022dB14470f4e011',
      polygonMumbaiAaveDaiAddress,
      aavePolygonMumbaiPool
    );

  await tokenFactory
    .connect(deployer)
    .initialize(
      await admin.getAddress(),
      tokenExchange.address,
      tokenLogic.address,
      networkManager.address
    );

  await tokenExchange
    .connect(deployer)
    .initialize(
      await admin.getAddress(),
      await admin.getAddress(),
      await admin.getAddress(),
      tokenFactory.address,
      interestManagerAave.address,
      '0xD40282e050723Ae26Aeb0F77022dB14470f4e011' //polygonMumbaiDaiAddress
    );

  await networkManager
    .connect(deployer)
    .initialize(
      tokenFactory.address,
      networkManager.address,
      await admin.getAddress(),
      lensHubPolygonMumbaiAddress,
      lensHubMumbaiProfileCreationProxyAddress,
      await admin.getAddress(),
      '0xD40282e050723Ae26Aeb0F77022dB14470f4e011' //polygonMumbaiDaiAddress
    );

  //add markets
  await waitForTx(
    tokenFactory.addMarket(
      'Writing and Translation',
      baseCost,
      priceRise,
      hatchTokens,
      tradingFeeRate,
      platformFeeRate,
      false
    )
  );

  await waitForTx(
    moduleGlobals.whitelistCurrency('0xD40282e050723Ae26Aeb0F77022dB14470f4e011'/*polygonMumbaiDaiAddress*/, true)
  )

  const TestnetAddresses = {
    InterestManagerAave: interestManagerAave.address,
    TokenExchange: tokenExchange.address,
    TokenFactory: tokenFactory.address,
    TokenLogic: tokenLogic.address,
    NetworkManager: networkManager.address
  };

  const json = JSON.stringify(TestnetAddresses, null, 2);
  console.log(TestnetAddresses);

  fs.writeFileSync('mumbai-testnet-addresses.json', json, 'utf-8');
});
