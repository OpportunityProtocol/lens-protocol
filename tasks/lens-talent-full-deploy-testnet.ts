//lens-talent-local-startup-util
import { task } from 'hardhat/config';
import {
  InterestManagerAave__factory,
  NetworkManager__factory,
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

const sandboxPolygonMumbaiLensHubProxy = '0x7582177F9E536aB0b6c721e11f383C326F2Ad1D5'
const sandboxPolygonMumbaiLensFeeCollectModule = '0xE98a40DB1170B3A46ffa7bA84335A0A0e9A65C2d'
const sandboxPolygonMumbaiLensFreeFollowModule = '0x11C45Cbc6fDa2dbe435C0079a2ccF9c4c7051595'
const sandboxPolygonMumbaiLensFollowOnlyReferenceModule = '0xB080AAc00E53FBeb04917F22096721d602c70759'
const sandboxPolygonMumbaiLensProfileCreator = '0x4fe8deB1cf6068060dE50aA584C3adf00fbDB87f'
const sandboxPolygonMumbaiLensInteractionLogic = '0x510f9D630644284AA3570FC28e797eA0ab47AAa3'

task(
  'lens-talent-testnet-full-deploy',
  'deploys lens talent'
).setAction(async ({}, hre) => {
  //hre.ethers.provider = new hre.ethers.providers.JsonRpcProvider(hre.ethers.provider.connection.url)
  //hre.run('compile')

  try {

  const ethers = hre.ethers;
  const signers = await ethers.getSigners();
  const admin: Signer = signers[0]
  const deployer = admin
  const deployerAddress = await admin.getAddress()
  console.log(deployerAddress)
  let deployerNonce = await ethers.provider.getTransactionCount(deployerAddress);

  console.log('Deploying contracts..')
  //DEPLOY CONTRACTS
  const interestManagerAave = await deployContract(
    new InterestManagerAave__factory(deployer).deploy({
      nonce: deployerNonce++
    })
  );

  console.log('TRY')

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

  console.log('Initializing contracts...')

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
      sandboxPolygonMumbaiLensHubProxy,
      sandboxPolygonMumbaiLensProfileCreator,
      await admin.getAddress(),
      polygonMumbaiDaiAddress
    );




  const TestnetAddresses = {
    InterestManagerAave: interestManagerAave.address,
    TokenExchange: tokenExchange.address,
    TokenFactory: tokenFactory.address,
    TokenLogic: tokenLogic.address,
    NetworkManager: networkManager.address,
    ServiceCollectModule: sandboxPolygonMumbaiLensFeeCollectModule,
    ServiceReferenceModule: sandboxPolygonMumbaiLensFollowOnlyReferenceModule
  };

  const json = JSON.stringify(TestnetAddresses, null, 2);
  console.log(TestnetAddresses);

  fs.writeFileSync('mumbai-testnet-addresses.json', json, 'utf-8');
} catch(error) {
  console.log(error)
}
});
