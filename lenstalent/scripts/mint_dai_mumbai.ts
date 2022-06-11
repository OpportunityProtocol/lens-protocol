import { Contract, ContractFactory } from "@ethersproject/contracts"
import { ethers } from "ethers"

//const { ethers } = require('hardhat')
import json from '../../artifacts/contracts/gigearth/util/ControlledERC20.sol/ControlledERC20.json'
import { ControlledERC20__factory } from '../../typechain-types/factories/ControlledERC20__factory'
async function main() {
    const provider = new ethers.providers.JsonRpcProvider(process.env.MUMBAI_RPC_URL)
    console.log(await provider.getCode('0x7589B39257F2B6Ea4d615994C1C9414b5144309c'))

}
 
 main()
   .then(() => process.exit(0))
   .catch(error => {
     console.error(error);
     process.exit(1);
   });