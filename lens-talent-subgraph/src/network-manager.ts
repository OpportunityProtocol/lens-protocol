import { BigInt, Bytes } from '@graphprotocol/graph-ts';
import {
  UserRegistered,
  ServiceCreated,
  ServicePurchased,
  ServiceResolved,
  ContractOwnershipUpdate,
  ContractCreated,
  MarketCreated,
} from '../generated/NetworkManager/NetworkManager';
import { Market, Service, PurchasedService, Contract } from '../generated/schema';

export function handleUserRegistered(event: UserRegistered): void {}
export function handleServiceCreated(event: ServiceCreated): void {
  const id = event.params.serviceId.toString();
  let service = Service.load(id);

  if (!service) {
    service = new Service(id);
    service.id = id;
    service.marketId = event.params.marketId;
    service.owner = event.params.creator;
    service.metadataPtr = event.params.metadataPtr;
    service.offers = event.params.offers;
    service.pubId = event.params.pubId;
    service.save();
  }
}
export function handleServicePurchased(event: ServicePurchased): void {
  const id = event.params.purchaseId.toString();
  let purchasedService = PurchasedService.load(id);

  if (purchasedService) {
    const linkedService = Service.load(event.params.serviceId.toString());

    if (linkedService) {
      purchasedService.metadata = linkedService.metadataPtr;
    } else {
      purchasedService.metadata = '';
    }

    if (!purchasedService) {
      purchasedService = new PurchasedService(id);
      purchasedService.id = id;
      purchasedService.client = event.params.purchaser;
      purchasedService.datePurchased = new BigInt(20);
      purchasedService.purchaseId = event.params.purchaseId;
      purchasedService.referral = event.params.referral;
      purchasedService.owner = event.params.owner;
      purchasedService.pubId = event.params.pubId;
      purchasedService.serviceId = event.params.serviceId;
      purchasedService.save();
    }
  }
}

export function handleServiceResolved(event: ServiceResolved): void {}
export function handleContractOwnershipUpdate(event: ContractOwnershipUpdate): void {
  const id = event.params.id.toString();
  let contract = Contract.load(id);

  if (contract) {
    contract.worker = event.params.worker;
    contract.ownership = event.params.ownership;
    contract.resolutionTimestamp = event.block.timestamp.toString(); //convert to if case
    contract.save();
  }
}
export function handleContractCreated(event: ContractCreated): void {
  const id = event.params.id.toString();
  let contract = Contract.load(id);

  if (!contract) {
    contract = new Contract(id);
    contract.id = id;
    contract.employer = event.params.creator;
    contract.marketId = event.params.marketId;
    contract.metadata = event.params.metadataPtr.toString();
    contract.acceptanceTimestamp = '0';
    contract.worker = new Bytes(0);
    contract.resolutionTimestamp = '0';
    contract.ownership = 0;
    contract.save();
  }
}
export function handleMarketCreated(event: MarketCreated): void {}
