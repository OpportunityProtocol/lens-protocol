//lens-talent-local-startup-util
import { task } from 'hardhat/config';
import {
  InterestManagerAave__factory,
  LensHub__factory,
  NetworkManager__factory,
  ServiceCollectModule__factory,
  ServiceToken__factory,
  TokenExchange__factory,
  TokenFactory,
  TokenFactory__factory,
} from '../typechain-types';
import { CreateProfileDataStruct } from '../typechain-types/LensHub';
import { waitForTx, initEnv, getAddrs, ZERO_ADDRESS, deployContract } from './helpers/utils';
import { BigNumber, Wallet, providers, Signer } from 'ethers';
import { Contract } from '@ethersproject/contracts';

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
  'starts the lens talent ui with appropriate data'
).setAction(async ({}, hre) => {
  hre.ethers.provider = new hre.ethers.providers.JsonRpcProvider(hre.ethers.provider.connection.url)
  hre.run('compile')

  const governance = await hre.ethers.getSigners()[0];
  const ethers = hre.ethers;
  const signers = await ethers.getSigners();
  const deployer = signers[0];

  const MATIC_BALACE = '0xFFFFFFFFFFFFFFFF';

  let deployerNonce = await ethers.provider.getTransactionCount(deployer.address);

  const admin: Signer = await ethers.getSigner('0xba77d43ee401a4c4a229c3649ccedbfe2b517208');

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

  await hre.run("graph", { 
    contractName: "NetworkManager", 
    address: networkManager.address 
  });

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
      networkManager.address,
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

  //ENABLE LENS OPERATIONS ON TESTNET
  await hre.network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [lensHubMumbaiGovernance],
  });

  await hre.network.provider.send('hardhat_setBalance', [
    lensHubPolygonMumbaiAddress,
    MATIC_BALACE,
  ]);

  const lensHubSigner = await ethers.getSigner(lensHubMumbaiGovernance);

  const lensHub = LensHub__factory.connect(lensHubPolygonMumbaiAddress, governance);

  await waitForTx(
    lensHub.connect(lensHubSigner).whitelistProfileCreator(networkManager.address, true)
  );

  await waitForTx(
    lensHub.connect(lensHubSigner).whitelistCollectModule(serviceCollectModule.address, true)
  );

  await hre.network.provider.request({
    method: 'hardhat_stopImpersonatingAccount',
    params: [lensHubMumbaiGovernance],
  });

  const mockTestnetAddresses = {
    InterestManagerAave: interestManagerAave.address,
    TokenExchange: tokenExchange.address,
    TokenFactory: tokenFactory.address,
    TokenLogic: tokenLogic.address,
    NetworkManager: networkManager.address,
    ServiceCollectModule: serviceCollectModule.address,
    ServiceReferenceModule: serviceReferenceModule.address
  };

  const json = JSON.stringify(mockTestnetAddresses, null, 2);
  console.log(mockTestnetAddresses);

  fs.writeFileSync('mock-testnet-addresses.json', json, 'utf-8');
});
