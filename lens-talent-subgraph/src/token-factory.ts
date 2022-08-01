import { BigInt, Bytes } from '@graphprotocol/graph-ts';
import { Market, Service, ServiceToken } from '../generated/schema';
import { NewMarket, NewToken } from '../generated/TokenFactory/TokenFactory';

export function handleNewServiceToken(event: NewToken): void {
  const id = event.params.id.toString();

  if (!ServiceToken.load(id)) {
    const newServiceToken = new ServiceToken(id);
    newServiceToken.id = id;
    newServiceToken.marketID = event.params.marketID;
    newServiceToken.name = event.params.name;
    newServiceToken.address = event.params.addr;
    newServiceToken.lister = event.params.lister;
    newServiceToken.save();
  }
}

export function handleNewMarket(event: NewMarket): void {
  const id = event.params.id.toString();

  if (!Market.load(id)) {
    const newMarket = new Market(id);
    newMarket.id = event.params.id.toString();
    newMarket.name = event.params.name;
    newMarket.baseCost = event.params.baseCost;
    newMarket.hatchTokens = event.params.hatchTokens;
    newMarket.priceRise = event.params.priceRise
    newMarket.tradingFeeRate = event.params.tradingFeeRate;
    newMarket.platformFeeRate = event.params.platformFeeRate;
    newMarket.allInterestToPlatform = event.params.allInterestToPlatform;
    newMarket.save();
  }
}
