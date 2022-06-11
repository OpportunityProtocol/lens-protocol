import { ethers } from 'ethers';

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(process.env.MUMBAI_RPC_URL);
  console.log(await provider.getCode('0x7589B39257F2B6Ea4d615994C1C9414b5144309c'));

  //mint dai

  //whitelist network manager as profile creator

  //create markets
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
