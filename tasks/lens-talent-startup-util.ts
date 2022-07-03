//lens-talent-local-startup-util
import { task } from 'hardhat/config';
import {
  LensHub__factory,
  NetworkManager__factory,
  TokenFactory,
  TokenFactory__factory,
} from '../typechain-types';
import { CreateProfileDataStruct } from '../typechain-types/LensHub';
import { waitForTx, initEnv, getAddrs, ZERO_ADDRESS } from './helpers/utils';
import addresses from '../addresses.json';
import ethers, { BigNumber, Wallet, providers } from 'ethers';
import { Contract } from '@ethersproject/contracts';

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

task('lens-talent-local-startup-util', 'starts the lens talent ui with appropriate data').setAction(
  async ({}, hre) => {
    const [governance, , user] = await initEnv(hre);
    const provider = new providers.JsonRpcProvider('http://localhost:8545');
    const addrs = getAddrs();
    const ethers = hre.ethers;
    const signers = await ethers.getSigners();
    const networkManager = LensHub__factory.connect(addresses['Network Manager: '], signers[0]);
    const lensHub = LensHub__factory.connect(addrs['lensHub proxy'], governance);
    const tokenFactory = await ethers.getContractAt(
      'TokenFactory',
      addresses['Token Factory: '],
      provider.getSigner()
    );

    const MOCK_PROFILE_URI = 'https://ipfs.io/ipfs/Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu';
    const MOCK_FOLLOW_NFT_URI =
      'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan';

    for (let i = 1; i < signers.length; i++) {
      await NetworkManager__factory.connect(
        addresses['Network Manager: '],
        signers[i]
      ).registerWorker({
        to: addresses['Network Manager: '],
        handle: handles[i],
        imageURI: MOCK_PROFILE_URI,
        followModule: '0x0000000000000000000000000000000000000000',
        followModuleInitData: [],
        followNFTURI: MOCK_FOLLOW_NFT_URI,
      });
    }

    //white list modules
    await waitForTx(lensHub.whitelistCollectModule(addresses['Service Collect Module: '], true));

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
      tokenFactory.addMarket(
        'Graphic Design',
        baseCost,
        priceRise,
        hatchTokens,
        tradingFeeRate,
        platformFeeRate,
        false
      )
    );

    await waitForTx(
      tokenFactory.addMarket(
        'IT and Software Development',
        baseCost,
        priceRise,
        hatchTokens,
        tradingFeeRate,
        platformFeeRate,
        false
      )
    );

    await waitForTx(
      tokenFactory.addMarket(
        'Human Resources',
        baseCost,
        priceRise,
        hatchTokens,
        tradingFeeRate,
        platformFeeRate,
        false
      )
    );

    await waitForTx(
      tokenFactory.addMarket(
        'Accounting and Finance',
        baseCost,
        priceRise,
        hatchTokens,
        tradingFeeRate,
        platformFeeRate,
        false
      )
    );

    for (let i = 1; i < signers.length; i++) {
      await NetworkManager__factory.connect(
        addresses['Network Manager: '],
        signers[i]
      ).createService(
        1,
        'https://ipfs.io/ipfs/Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu',
        [1000, 2000, 3000],
        0,
        addresses['Service Collect Module: ']
      );
    }
  }
);
