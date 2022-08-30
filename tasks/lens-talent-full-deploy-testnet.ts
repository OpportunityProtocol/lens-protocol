//lens-talent-local-startup-util
import { task } from 'hardhat/config';
import {
  InterestManagerAave__factory,
  NetworkManager__factory,
  ServiceCollectModule__factory,
  ServiceToken__factory,
  TokenExchange__factory,
  TokenFactory__factory,
} from '../typechain-types';
import {  deployContract } from './helpers/utils';
import { Signer } from 'ethers';

import fs from 'fs';
import {
  polygonMumbaiAaveDaiAddress,
  aavePolygonMumbaiPool,
  lensHubMumbaiGovernance,
  lensHubMumbaiProfileCreationProxyAddress,
  lensHubPolygonMumbaiAddress,
  lensMumbaiModuleGlobalPolygonMumbaiAddress,
  polygonMumbaiDaiAddress,
} from './constants';

task(
  'lens-talent-testnet-full-deploy',
  'deploys lens talent'
).setAction(async ({}, hre) => {
  hre.ethers.provider = new hre.ethers.providers.JsonRpcProvider(hre.ethers.provider.connection.url)
  hre.run('compile')

  const ethers = hre.ethers;
  const signers = await ethers.getSigners();
  const deployer = signers[0];
  const admin: Signer = await ethers.getSigner('0xba77d43ee401a4c4a229c3649ccedbfe2b517208');

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

  const serviceCollectModule = await deployContract(
    new ServiceCollectModule__factory(deployer).deploy(
      lensHubPolygonMumbaiAddress,
      lensMumbaiModuleGlobalPolygonMumbaiAddress,
      networkManager.address,
      {
        nonce: deployerNonce++,
      }
    )
  );

  const serviceReferenceModule = await deployContract(
    new ServiceCollectModule__factory(deployer).deploy(
      lensHubPolygonMumbaiAddress,
      lensMumbaiModuleGlobalPolygonMumbaiAddress,
      networkManager.address,
      {
        nonce: deployerNonce++
      }
    )
  )

  //INITIALIZE CONTRACTS
  await interestManagerAave
    .connect(deployer)
    .initialize(
      await admin.getAddress(),
      polygonMumbaiDaiAddress,
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
      polygonMumbaiDaiAddress
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
      polygonMumbaiDaiAddress
    );


  const TestnetAddresses = {
    InterestManagerAave: interestManagerAave.address,
    TokenExchange: tokenExchange.address,
    TokenFactory: tokenFactory.address,
    TokenLogic: tokenLogic.address,
    NetworkManager: networkManager.address,
    ServiceCollectModule: serviceCollectModule.address,
    ServiceReferenceModule: serviceReferenceModule.address
  };

  const json = JSON.stringify(TestnetAddresses, null, 2);
  console.log(TestnetAddresses);

  fs.writeFileSync('mumbai-testnet-addresses.json', json, 'utf-8');
});
