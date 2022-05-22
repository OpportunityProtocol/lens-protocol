import { AbiCoder } from '@ethersproject/abi';
import { parseEther } from '@ethersproject/units';
import '@nomiclabs/hardhat-ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect, use } from 'chai';
import { solidity } from 'ethereum-waffle';
import { BytesLike, Signer, Wallet, BigNumber } from 'ethers';
import { ethers } from 'hardhat';

import {
  ApprovalFollowModule,
  ApprovalFollowModule__factory,
  CollectNFT__factory,
  Currency,
  Currency__factory,
  FreeCollectModule,
  FreeCollectModule__factory,
  Events,
  Events__factory,
  FeeCollectModule,
  FeeCollectModule__factory,
  FeeFollowModule,
  FeeFollowModule__factory,
  FollowerOnlyReferenceModule,
  FollowerOnlyReferenceModule__factory,
  FollowNFT__factory,
  Helper,
  Helper__factory,
  InteractionLogic__factory,
  LensHub,
  LensHub__factory,
  LimitedFeeCollectModule,
  LimitedFeeCollectModule__factory,
  LimitedTimedFeeCollectModule,
  LimitedTimedFeeCollectModule__factory,
  MockFollowModule,
  MockFollowModule__factory,
  MockReferenceModule,
  MockReferenceModule__factory,
  ModuleGlobals,
  ModuleGlobals__factory,
  ProfileTokenURILogic__factory,
  PublishingLogic__factory,
  RelationshipFollowModule,
  RevertCollectModule,
  RevertCollectModule__factory,
  SimpleCentralizedArbitrator,
  TimedFeeCollectModule,
  TimedFeeCollectModule__factory,
  TransparentUpgradeableProxy__factory,
  RelationshipFollowModule__factory,
  SimpleCentralizedArbitrator__factory,
  LensPeriphery,
  LensPeriphery__factory,
  ProfileFollowModule,
  ProfileFollowModule__factory,
  FollowNFT,
  CollectNFT,
  RevertFollowModule,
  RevertFollowModule__factory,
  TokenFactory__factory,
  TokenExchange__factory,
  TokenVault__factory,
  MultiAction__factory,
  InterestManagerCompound__factory,
  ServiceToken__factory,
  ProxyAdmin__factory,
  AdminUpgradeabilityProxy__factory,
  TestERC20__factory,
  TestComptroller__factory,
  TestCDai__factory,
  TestERC20,
  TestComptroller,
  TestCDai,
  InterestManagerCompound,
  ServiceToken,
  TokenFactory,
  ProxyAdmin,
  TokenExchange,
  AdminUpgradeabilityProxy,
  TokenVault,
  TestUniswapV2Router02,
  TestUniswapV2Router02__factory,
  TestUniswapV2Factory,
  TestUniswapV2Factory__factory,
  MultiAction,
  NetworkManager__factory,
  GigEarthContentReferenceModule,
  NetworkManager,
  GigEarthContentReferenceModule__factory,
} from '../typechain-types';
import { LensHubLibraryAddresses } from '../typechain-types/factories/LensHub__factory';
import { FAKE_PRIVATEKEY, ZERO_ADDRESS } from './helpers/constants';
import {
  computeContractAddress,
  ProtocolState,
  revertToSnapshot,
  takeSnapshot,
} from './helpers/utils';

use(solidity);

export const CURRENCY_MINT_AMOUNT = parseEther('100');
export const BPS_MAX = 10000;
export const TREASURY_FEE_BPS = 50;
export const REFERRAL_FEE_BPS = 250;
export const MAX_PROFILE_IMAGE_URI_LENGTH = 6000;
export const LENS_HUB_NFT_NAME = 'Lens Protocol Profiles';
export const LENS_HUB_NFT_SYMBOL = 'LPP';
export const MOCK_PROFILE_HANDLE = 'plant1ghost.eth';
export const LENS_PERIPHERY_NAME = 'LensPeriphery';
export const FIRST_PROFILE_ID = 1;
export const MOCK_URI = 'https://ipfs.io/ipfs/QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR';
export const OTHER_MOCK_URI = 'https://ipfs.io/ipfs/QmSfyMcnh1wnJHrAWCBjZHapTS859oNSsuDFiAPPdAHgHP';
export const MOCK_PROFILE_URI =
  'https://ipfs.io/ipfs/Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu';
export const MOCK_FOLLOW_NFT_URI =
  'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan';

export let accounts: SignerWithAddress[];
export let deployer: Signer;
export let user: Signer;
export let userTwo: Signer;
export let userThree: Signer;
export let governance: Signer;
export let deployerAddress: string;
export let userAddress: string;
export let userTwoAddress: string;
export let userThreeAddress: string;
export let governanceAddress: string;
export let treasuryAddress: string;
export let testWallet: Wallet;
export let lensHubImpl: LensHub;
export let lensHub: LensHub;
export let currency: Currency;
export let abiCoder: AbiCoder;
export let mockModuleData: BytesLike;
export let hubLibs: LensHubLibraryAddresses;
export let eventsLib: Events;
export let moduleGlobals: ModuleGlobals;
export let helper: Helper;
export let gigEarthGovernance: Signer;
export let gigEarthTreasury: Signer;
export let employer: Signer;
export let worker: Wallet;
export let employerAddress: string;
export let workerAddress: string;
export let lensPeriphery: LensPeriphery;
export let followNFTImpl: FollowNFT;
export let collectNFTImpl: CollectNFT;

/* Modules */

// Collect
export let feeCollectModule: FeeCollectModule;
export let timedFeeCollectModule: TimedFeeCollectModule;
export let freeCollectModule: FreeCollectModule;
export let revertCollectModule: RevertCollectModule;
export let limitedFeeCollectModule: LimitedFeeCollectModule;
export let limitedTimedFeeCollectModule: LimitedTimedFeeCollectModule;
export let gigEarth: NetworkManager
export let simpleArbitrator: SimpleCentralizedArbitrator

// Follow
export let approvalFollowModule: ApprovalFollowModule;
export let profileFollowModule: ProfileFollowModule;
export let feeFollowModule: FeeFollowModule;
export let revertFollowModule: RevertFollowModule;
export let mockFollowModule: MockFollowModule;
export let relationshipFollowModule: RelationshipFollowModule

// Reference
export let followerOnlyReferenceModule: FollowerOnlyReferenceModule;
export let mockReferenceModule: MockReferenceModule;
export let relationshipReferenceModule: GigEarthContentReferenceModule

//ideamarket core
export let dai: TestERC20;
export let comp: TestERC20;
export let wEth: TestERC20
export let comptroller: TestComptroller;
export let cDai: TestCDai;
export let interestManagerCompound: InterestManagerCompound;
export let ideaTokenLogic: ServiceToken;
export let ideaTokenFactory: TokenFactory;
export let proxyAdmin: ProxyAdmin;
export let ideaTokenExchangeLogic: TokenExchange;
export let ideaTokenExchangeInitCall
export let ideaTokenExchange: TokenExchange
export let ideaTokenExchangeProxy: AdminUpgradeabilityProxy;
export let tokenVault: TokenVault;
export let uniswapV2Router02: TestUniswapV2Router02
export let uniswapV2Factory: TestUniswapV2Factory
export let multiAction: MultiAction

export const tenPow18 = BigNumber.from('1000000000000000000')
export let adminAccount: Signer
export let adminAccountAddress
export const zeroAddress = '0x0000000000000000000000000000000000000000'
export const oneAddress = '0x0000000000000000000000000000000000000001'
export const twoAddress = '0x0000000000000000000000000000000000000002'
export const baseCost = BigNumber.from('100000000000000000') // 10**17 = $0.1
export const priceRise = BigNumber.from('100000000000000') // 10**14 = $0.0001
export const hatchTokens = BigNumber.from('1000000000000000000000') // 10**21 = 1000
export const tradingFeeRate = BigNumber.from('100')
export const platformFeeRate = BigNumber.from('50')

export function makeSuiteCleanRoom(name: string, tests: () => void) {
  describe(name, () => {
    beforeEach(async function () {
      await takeSnapshot();
    });
    tests();
    afterEach(async function () {
      await revertToSnapshot();
    });
  });
}

before(async function () {
  abiCoder = ethers.utils.defaultAbiCoder;
  testWallet = new ethers.Wallet(FAKE_PRIVATEKEY).connect(ethers.provider);
  accounts = await ethers.getSigners();
  deployer = accounts[0];
  user = accounts[1];
  userTwo = accounts[2];
  userThree = accounts[4];
  governance = accounts[3];
  gigEarthGovernance = accounts[4]
  adminAccount = gigEarthGovernance
  adminAccountAddress = await gigEarthGovernance.getAddress()
  gigEarthTreasury = accounts[5]
  employer = new ethers.Wallet('0x275cc4a2bfd4f612625204a20a2280ab53a6da2d14860c47a9f5affe58ad86d4').connect(ethers.provider)
  worker = new ethers.Wallet('0xc5e8f61d1ab959b397eecc0a37a6517b8e67a0e7cf1f4bce5591f3ed80199122').connect(ethers.provider);


  deployerAddress = await deployer.getAddress();
  userAddress = await user.getAddress();
  userTwoAddress = await userTwo.getAddress();
  userThreeAddress = await userThree.getAddress();
  governanceAddress = await governance.getAddress();
  treasuryAddress = await accounts[4].getAddress();
  employerAddress = await accounts[6].getAddress()
  workerAddress = await accounts[7].getAddress()
  mockModuleData = abiCoder.encode(['uint256'], [1]);

  // Deployment
  helper = await new Helper__factory(deployer).deploy();
  moduleGlobals = await new ModuleGlobals__factory(deployer).deploy(
    governanceAddress,
    treasuryAddress,
    TREASURY_FEE_BPS
  );
  const publishingLogic = await new PublishingLogic__factory(deployer).deploy();
  const interactionLogic = await new InteractionLogic__factory(deployer).deploy();
  const profileTokenURILogic = await new ProfileTokenURILogic__factory(deployer).deploy();
  hubLibs = {
    'contracts/libraries/PublishingLogic.sol:PublishingLogic': publishingLogic.address,
    'contracts/libraries/InteractionLogic.sol:InteractionLogic': interactionLogic.address,
    'contracts/libraries/ProfileTokenURILogic.sol:ProfileTokenURILogic':
      profileTokenURILogic.address,
  };

  // Here, we pre-compute the nonces and addresses used to deploy the contracts.
  const nonce = await deployer.getTransactionCount();
  // nonce + 0 is follow NFT impl
  // nonce + 1 is collect NFT impl
  // nonce + 2 is impl
  // nonce + 3 is hub proxy

  const hubProxyAddress = computeContractAddress(deployerAddress, nonce + 3); //'0x' + keccak256(RLP.encode([deployerAddress, hubProxyNonce])).substr(26);

  followNFTImpl = await new FollowNFT__factory(deployer).deploy(hubProxyAddress);
  collectNFTImpl = await new CollectNFT__factory(deployer).deploy(hubProxyAddress);

  lensHubImpl = await new LensHub__factory(hubLibs, deployer).deploy(
    followNFTImpl.address,
    collectNFTImpl.address
  );

  let data = lensHubImpl.interface.encodeFunctionData('initialize', [
    LENS_HUB_NFT_NAME,
    LENS_HUB_NFT_SYMBOL,
    governanceAddress,
  ]);

  let proxy = await new TransparentUpgradeableProxy__factory(deployer).deploy(
    lensHubImpl.address,
    deployerAddress,
    data
  );


  // Connect the hub proxy to the LensHub factory and the user for ease of use.
  lensHub = LensHub__factory.connect(proxy.address, user);

  dai = await new TestERC20__factory(deployer).deploy('DAI', 'DAI')
  await dai.deployed()

  comp = await new TestERC20__factory(deployer).deploy('COMP', 'COMP')
  await comp.deployed()

  comptroller = await new TestComptroller__factory(deployer).deploy()
  await comptroller.deployed()

  cDai = await new TestCDai__factory(deployer).deploy(dai.address, comp.address, comptroller.address)
  await cDai.deployed()
  await cDai.setExchangeRate(tenPow18)

  tokenVault = await new TokenVault__factory(deployer).deploy()
  await tokenVault.deployed()

  wEth = await new TestERC20__factory(deployer).deploy('WETH', 'WETH')
  await wEth.deployed()

  uniswapV2Factory = await new TestUniswapV2Factory__factory(deployer).deploy(zeroAddress)
  uniswapV2Router02 = await new TestUniswapV2Router02__factory(deployer).deploy(uniswapV2Factory.address, wEth.address)

  simpleArbitrator = await new SimpleCentralizedArbitrator__factory(deployer).deploy()
  await simpleArbitrator.deployed()

  gigEarth = await new NetworkManager__factory(deployer).deploy(await gigEarthGovernance.getAddress(), await gigEarthTreasury.getAddress(), simpleArbitrator.address, proxy.address, dai.address)
  await gigEarth.deployed()

  //deploy core
  interestManagerCompound = await new InterestManagerCompound__factory(deployer).deploy()
  await interestManagerCompound.deployed()

  ideaTokenLogic = await new ServiceToken__factory(deployer).deploy()
  await ideaTokenLogic.deployed()

  ideaTokenFactory = await new TokenFactory__factory(deployer).deploy()
  await ideaTokenFactory.deployed()

  ideaTokenExchange = await new TokenExchange__factory(deployer).deploy()
  await ideaTokenExchange.deployed()

  multiAction = await new MultiAction__factory(deployer).deploy(ideaTokenExchange.address, ideaTokenFactory.address, tokenVault.address, dai.address, uniswapV2Router02.address, wEth.address)
  await multiAction.deployed()

  relationshipReferenceModule = await new GigEarthContentReferenceModule__factory(deployer).deploy(moduleGlobals.address)

  await gigEarth.initialize(adminAccountAddress, ideaTokenFactory.address)

  await interestManagerCompound
    .connect(adminAccount)
    .initialize(ideaTokenExchange.address, dai.address, cDai.address, comp.address, oneAddress)

  await ideaTokenFactory
    .connect(adminAccount)
    .initialize(adminAccountAddress, ideaTokenExchange.address, ideaTokenLogic.address, gigEarth.address)

  await ideaTokenExchange
    .connect(adminAccount)
    .initialize(
      adminAccountAddress,
      adminAccountAddress,
      await gigEarthTreasury.getAddress(),
      interestManagerCompound.address,
      dai.address
    )


  await ideaTokenExchange.connect(adminAccount).setTokenFactoryAddress(ideaTokenFactory.address)

  // await gigEarth.connect(gigEarthGovernance).setLensContentReferenceModule(relationshipReferenceModule.address)
  //await gigEarth.connect(gigEarthGovernance).setLensFollowModule(relationshipFollowModule.address)

  // LensPeriphery
  lensPeriphery = await new LensPeriphery__factory(deployer).deploy(lensHub.address);
  lensPeriphery = lensPeriphery.connect(user);

  // Currency
  currency = await new Currency__factory(deployer).deploy();

  // Modules
  freeCollectModule = await new FreeCollectModule__factory(deployer).deploy(lensHub.address);
  revertCollectModule = await new RevertCollectModule__factory(deployer).deploy();
  feeCollectModule = await new FeeCollectModule__factory(deployer).deploy(
    lensHub.address,
    moduleGlobals.address
  );
  timedFeeCollectModule = await new TimedFeeCollectModule__factory(deployer).deploy(
    lensHub.address,
    moduleGlobals.address
  );
  limitedFeeCollectModule = await new LimitedFeeCollectModule__factory(deployer).deploy(
    lensHub.address,
    moduleGlobals.address
  );
  limitedTimedFeeCollectModule = await new LimitedTimedFeeCollectModule__factory(deployer).deploy(
    lensHub.address,
    moduleGlobals.address
  );

  feeFollowModule = await new FeeFollowModule__factory(deployer).deploy(
    lensHub.address,
    moduleGlobals.address
  );
  profileFollowModule = await new ProfileFollowModule__factory(deployer).deploy(lensHub.address);
  approvalFollowModule = await new ApprovalFollowModule__factory(deployer).deploy(lensHub.address);
  revertFollowModule = await new RevertFollowModule__factory(deployer).deploy(lensHub.address);
  followerOnlyReferenceModule = await new FollowerOnlyReferenceModule__factory(deployer).deploy(
    lensHub.address
  );

  mockFollowModule = await new MockFollowModule__factory(deployer).deploy();
  mockReferenceModule = await new MockReferenceModule__factory(deployer).deploy();

  await expect(lensHub.connect(governance).setState(ProtocolState.Unpaused)).to.not.be.reverted;
  await expect(
    lensHub.connect(governance).whitelistProfileCreator(userAddress, true)
  ).to.not.be.reverted;
  await expect(
    lensHub.connect(governance).whitelistProfileCreator(userTwoAddress, true)
  ).to.not.be.reverted;
  await expect(
    lensHub.connect(governance).whitelistProfileCreator(userThreeAddress, true)
  ).to.not.be.reverted;
  await expect(
    lensHub.connect(governance).whitelistProfileCreator(testWallet.address, true)
  ).to.not.be.reverted;
  await expect(
    lensHub.connect(governance).whitelistProfileCreator(gigEarth.address, true)
  ).to.not.be.reverted;
  await expect(
    lensHub.connect(governance).whitelistReferenceModule(relationshipReferenceModule.address, true)
  ).to.not.be.reverted;

  expect(lensHub).to.not.be.undefined;
  expect(currency).to.not.be.undefined;
  expect(timedFeeCollectModule).to.not.be.undefined;
  expect(mockFollowModule).to.not.be.undefined;
  expect(mockReferenceModule).to.not.be.undefined;

  // Event library deployment is only needed for testing and is not reproduced in the live environment
  eventsLib = await new Events__factory(deployer).deploy();
});
