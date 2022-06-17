import { task } from 'hardhat/config';
import { LensHub__factory, NetworkManager__factory } from '../typechain-types';
import { CreateProfileDataStruct } from '../typechain-types/LensHub';
import { waitForTx, initEnv, getAddrs, ZERO_ADDRESS } from './helpers/utils';
import ethers, { Wallet } from 'ethers'

task('create-profile', 'creates a profile').setAction(async ({}, hre) => {
  const [governance, user] = await initEnv(hre);
  const addrs = getAddrs();
  const lensHub = LensHub__factory.connect(addrs['lensHub proxy'], governance);

  console.log(await lensHub.whitelistProfileCreator('0x393635397d4490365cb6FA9b2180663E2eE72468', true));

 /* const inputStruct: CreateProfileDataStruct = {
    to: '0x393635397d4490365cb6FA9b2180663E2eE72468',
    handle: 'zer0dot',
    imageURI: 'https://ipfs.io/ipfs/QmY9dUwYu67puaWBMxRKW98LPbXCznPwHUbhX5NeWnCJbX',
    followModule: ZERO_ADDRESS,
    followModuleInitData: [],
    followNFTURI: 'https://ipfs.io/ipfs/QmTFLSXdEQ6qsSzaXaCSNtiv6wA56qq87ytXJ182dXDQJS',
  };

  const signer = Wallet.fromMnemonic("moment insane wrong fringe seat twice cinnamon patrol gloom toddler tilt memory")

  await waitForTx(lensHub.connect(signer).createProfile(inputStruct));

  console.log(`Total supply (should be 1): ${await lensHub.totalSupply()}`);
  console.log(
    `Profile owner: ${await lensHub.ownerOf(1)}, user address (should be the same): 0x393635397d4490365cb6FA9b2180663E2eE72468`
  );
  console.log(`Profile ID by handle: ${await lensHub.getProfileIdByHandle('zer0dot')}`);*/
});
