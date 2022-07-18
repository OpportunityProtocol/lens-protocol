//lens-talent-local-startup-util
import { task } from 'hardhat/config';

import ethers, { BigNumber, Wallet, providers, Signer } from 'ethers';
import { Contract } from '@ethersproject/contracts';
import addresses from '../mock-testnet-addresses.json';
import { DAI_ABI, lensHubPolygonMumbaiAddress, polygonMumbaiDaiAddress } from './constants';

task('set-balances', 'starts the lens talent ui with appropriate data').setAction(
  async ({}, hre) => {
    hre.ethers.provider = new hre.ethers.providers.JsonRpcProvider(
      hre.ethers.provider.connection.url
    );
    const MATIC_BALACE = '0xFFFFFFFFFFFFFFFF';
    const ethers = hre.ethers;
    const admin: Signer = await ethers.getSigner('0xba77d43ee401a4c4a229c3649ccedbfe2b517208');

    const daiContract = new ethers.Contract(polygonMumbaiDaiAddress, DAI_ABI, hre.ethers.provider);
    daiContract.connect(admin)['mint(address,uint256)']('0xba77d43ee401a4c4a229c3649ccedbfe2b517208','20000')
/*

    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [lensHubPolygonMumbaiAddress],
    });

    await hre.network.provider.send('hardhat_setBalance', [
      lensHubPolygonMumbaiAddress,
      MATIC_BALACE,
    ]);

    await hre.network.provider.request({
      method: 'hardhat_stopImpersonatingAccount',
      params: [lensHubPolygonMumbaiAddress],
    });

    await hre.network.provider.send('hardhat_setBalance', [await admin.getAddress(), MATIC_BALACE]);*/
  }
);
