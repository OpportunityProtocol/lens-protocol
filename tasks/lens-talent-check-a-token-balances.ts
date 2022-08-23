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
import ethers, { BigNumber, Wallet, providers, Signer } from 'ethers';
import { Contract } from '@ethersproject/contracts';

import addresses from '../addresses.json';
import {
  aavePolygonMumbaiPool,
  DAI_ABI,
  lensHubPolygonMumbaiAddress,
  polygonMumbaiAaveDaiAddress,
  polygonMumbaiAaveDaiStableAddress,
  polygonMumbaiAaveDaiVariableAddress,
  polygonMumbaiDaiAddress,
  POLYGON_MUMBAI_AAVE_DAI_ABI,
  POLYGON_MUMBAI_AAVE_DAI_STABLE_ABI,
  POLYGON_MUMBAI_AAVE_DAI_VARIABLE_ABI,
} from './constants';

task('lens-talent-check-a-token-balances', 'checks aave balances').setAction(async ({}, hre) => {
  hre.ethers.provider = new hre.ethers.providers.JsonRpcProvider(
    hre.ethers.provider.connection.url
  );
  const ethers = hre.ethers;
  const signers = await ethers.getSigners();
  const admin: Signer = await ethers.getSigner('0xba77d43ee401a4c4a229c3649ccedbfe2b517208');

  const networkManager = NetworkManager__factory.connect(addresses['Network Manager'], admin);
  const dai = new Contract(polygonMumbaiDaiAddress, DAI_ABI, admin);
  
  const aPolMumbaiDaiToken= new ethers.Contract(
    aavePolygonMumbaiPool,
    ["function getUserAccountData(address user)"],
    admin
  );

  const aPolMumbaiDaiStable = new hre.ethers.Contract(
    polygonMumbaiAaveDaiStableAddress,
    ["function principalBalanceOf(address user) external view returns (uint256)",
  "function balanceOf(address account) public view returns (uint256)"],
    admin
  );

  const getBalances = async () => {
    let h = await aPolMumbaiDaiToken.getUserAccountData(addresses['Network Manager'])
    console.log(h)
  };

  console.log('Starting to check aave balances....');
  getBalances();
  console.log('Ending check of aave balances....');
});
