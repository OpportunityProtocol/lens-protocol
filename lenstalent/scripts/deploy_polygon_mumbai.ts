import { Contract, ContractFactory } from "@ethersproject/contracts"

const { ethers } = require('hardhat')

async function main() {

    const admin = '0xd72f5B8Eee99702C32AA45Dd8b41c7c8325Fbbc8'
    const polygonMumbaiDai = '0x001B3B4d0F3714Ca98ba10F6042DaEbF0B1B7b6F'
    const aDaiAddress = '0xDD4f3Ee61466C4158D394d57f3D4C397E91fBc51'
    const aavePool = '0x6C9fB0D5bD9429eb9Cd96B85B81d872281771E6B'
    const lensHub = '0x60Ae865ee4C725cd04353b5AAb364553f56ceF82'

    const NetworkManager: ContractFactory = await ethers.getContractFactory('NetworkManager')
    const TokenFactory: ContractFactory  = await ethers.getContractFactory('TokenFactory')
    const TokenExchange: ContractFactory  = await ethers.getContractFactory('TokenExchange')
    const ServiceToken: ContractFactory  = await ethers.getContractFactory('ServiceToken')
    const InterestManager: ContractFactory  = await ethers.getContractFactory('InterestManagerAave')

    const interestManager: Contract = await InterestManager.deploy()
    const tokenExchange: Contract = await TokenExchange.deploy()
    const tokenFactory: Contract = await TokenFactory.deploy()
    const serviceTokenLogic: Contract = await ServiceToken.deploy()
    const networkManager: Contract = await NetworkManager.deploy()

    await interestManager.initialize(networkManager.address, polygonMumbaiDai, aDaiAddress, aavePool)
    await tokenFactory.initialize(admin, tokenExchange.address, serviceTokenLogic.address, networkManager.address)
    await tokenExchange.initialize(admin, admin, admin, interestManager.address, polygonMumbaiDai)
    await networkManager.initialize(admin, tokenFactory.address, admin, admin, lensHub, admin, polygonMumbaiDai)

    const addresses = JSON.stringify({
      'Interest Manager':     await (await interestManager.deployed()).resolvedAddress,
      'Token Exchange': + await (await tokenExchange.deployed()).resolvedAddress,
      'Token Factory': + await (await tokenFactory.deployed()).resolvedAddress,
      'Token Logic': await (await serviceTokenLogic.deployed()).resolvedAddress,
      'Network Manager': + await (await networkManager.deployed()).resolvedAddress
    })

    console.log('Interest Manager: ', await (await interestManager.deployed()).resolvedAddress)
    console.log('Token Exchange: ', await (await tokenExchange.deployed()).resolvedAddress)
    console.log('Token Factory: ', await (await tokenFactory.deployed()).resolvedAddress)
    console.log('Token Logic: ', await (await serviceTokenLogic.deployed()).resolvedAddress)
    console.log('Network Manager: ', await (await networkManager.deployed()).resolvedAddress)
 }
 
 main()
   .then(() => process.exit(0))
   .catch(error => {
     console.error(error);
     process.exit(1);
   });