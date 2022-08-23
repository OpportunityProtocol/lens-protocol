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
import { DAI_ABI, lensHubPolygonMumbaiAddress, polygonMumbaiDaiAddress } from './constants';

const tenPow18 = BigNumber.from('1000000000000000000');
const zeroAddress = '0x0000000000000000000000000000000000000000';
const oneAddress = '0x0000000000000000000000000000000000000001';
const twoAddress = '0x0000000000000000000000000000000000000002';
const baseCost = BigNumber.from('100000000000000000'); // 10**17 = $0.1
const priceRise = BigNumber.from('100000000000000'); // 10**14 = $0.0001
const hatchTokens = BigNumber.from('1000000000000000000000'); // 10**21 = 1000
const tradingFeeRate = BigNumber.from('100');
const platformFeeRate = BigNumber.from('50');

const handles = [
  'babys1',
  'babys2',
  'babys3',
  'babys4',
  'babys5',
  'babys6',
  'babys7',
  'babys8',
  'babys9',
  'babys10',
  'babys11',
];

task('lens-talent-configure-markets', 'starts the lens talent ui with appropriate data').setAction(
  async ({}, hre) => {
    hre.ethers.provider = new hre.ethers.providers.JsonRpcProvider(hre.ethers.provider.connection.url);
    const ethers = hre.ethers;
    const signers = await ethers.getSigners();
    const admin: Signer = await ethers.getSigner('0xba77d43ee401a4c4a229c3649ccedbfe2b517208');

    const tokenFactory = TokenFactory__factory.connect(addresses['Token Factory'], admin);
    const networkManager = NetworkManager__factory.connect(addresses['Network Manager'], admin);
    const dai = new Contract(polygonMumbaiDaiAddress, DAI_ABI, admin);

    const MOCK_PROFILE_URI = 'https://ipfs.io/ipfs/Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu';
    const MOCK_FOLLOW_NFT_URI =
      'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan';

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


    await networkManager.connect(signers[6]).register({
      to: addresses['Network Manager'],
      handle: handles[6],
      imageURI: MOCK_PROFILE_URI,
      followModule: '0x0000000000000000000000000000000000000000',
      followModuleInitData: [],
      followNFTURI: MOCK_FOLLOW_NFT_URI,
    },

  'https://ipfs.io/ipfs/Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu',

    );

    await networkManager.connect(signers[1]).register({
      to: addresses['Network Manager'],
      handle: handles[7],
      imageURI: MOCK_PROFILE_URI,
      followModule: '0x0000000000000000000000000000000000000000',
      followModuleInitData: [],
      followNFTURI: MOCK_FOLLOW_NFT_URI,
    },
    'https://ipfs.io/ipfs/Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu',
    );

    await networkManager
      .connect(signers[6])
      .createService(
        1,
        'https://ipfs.io/ipfs/Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu',
        [1000, 2000, 3000],
        addresses['Service Collect Module'],
        addresses['Service Reference Module']
      );

    await networkManager
      .connect(signers[1])
      .createService(
        1,
        'https://ipfs.io/ipfs/Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu',
        [1000, 2000, 3000],
        addresses['Service Collect Module'],
        addresses['Service Reference Module']
      );

    //create contracts

    await networkManager.connect(signers[1])
    .createContract(1, 'https://ipfs.io/ipfs/Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu')

    await networkManager.connect(admin).createContract(1, 'https://ipfs.io/ipfs/Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu')

    console.log('Minting dai...')
    await dai.functions['mint(uint256)'](10000)
    console.log('Finish minting dai...')
  }
);