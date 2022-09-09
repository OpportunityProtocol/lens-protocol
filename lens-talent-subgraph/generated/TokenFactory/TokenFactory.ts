// THIS IS AN AUTOGENERATED FILE. DO NOT EDIT THIS FILE DIRECTLY.

import {
  ethereum,
  JSONValue,
  TypedMap,
  Entity,
  Bytes,
  Address,
  BigInt
} from "@graphprotocol/graph-ts";

export class NewMarket extends ethereum.Event {
  get params(): NewMarket__Params {
    return new NewMarket__Params(this);
  }
}

export class NewMarket__Params {
  _event: NewMarket;

  constructor(event: NewMarket) {
    this._event = event;
  }

  get id(): BigInt {
    return this._event.parameters[0].value.toBigInt();
  }

  get name(): string {
    return this._event.parameters[1].value.toString();
  }

  get baseCost(): BigInt {
    return this._event.parameters[2].value.toBigInt();
  }

  get priceRise(): BigInt {
    return this._event.parameters[3].value.toBigInt();
  }

  get hatchTokens(): BigInt {
    return this._event.parameters[4].value.toBigInt();
  }

  get tradingFeeRate(): BigInt {
    return this._event.parameters[5].value.toBigInt();
  }

  get platformFeeRate(): BigInt {
    return this._event.parameters[6].value.toBigInt();
  }

  get allInterestToPlatform(): boolean {
    return this._event.parameters[7].value.toBoolean();
  }
}

export class NewPlatformFee extends ethereum.Event {
  get params(): NewPlatformFee__Params {
    return new NewPlatformFee__Params(this);
  }
}

export class NewPlatformFee__Params {
  _event: NewPlatformFee;

  constructor(event: NewPlatformFee) {
    this._event = event;
  }

  get marketID(): BigInt {
    return this._event.parameters[0].value.toBigInt();
  }

  get platformFeeRate(): BigInt {
    return this._event.parameters[1].value.toBigInt();
  }
}

export class NewToken extends ethereum.Event {
  get params(): NewToken__Params {
    return new NewToken__Params(this);
  }
}

export class NewToken__Params {
  _event: NewToken;

  constructor(event: NewToken) {
    this._event = event;
  }

  get id(): BigInt {
    return this._event.parameters[0].value.toBigInt();
  }

  get marketID(): BigInt {
    return this._event.parameters[1].value.toBigInt();
  }

  get name(): string {
    return this._event.parameters[2].value.toString();
  }

  get addr(): Address {
    return this._event.parameters[3].value.toAddress();
  }

  get lister(): Address {
    return this._event.parameters[4].value.toAddress();
  }
}

export class NewTradingFee extends ethereum.Event {
  get params(): NewTradingFee__Params {
    return new NewTradingFee__Params(this);
  }
}

export class NewTradingFee__Params {
  _event: NewTradingFee;

  constructor(event: NewTradingFee) {
    this._event = event;
  }

  get marketID(): BigInt {
    return this._event.parameters[0].value.toBigInt();
  }

  get tradingFeeRate(): BigInt {
    return this._event.parameters[1].value.toBigInt();
  }
}

export class OwnershipChanged extends ethereum.Event {
  get params(): OwnershipChanged__Params {
    return new OwnershipChanged__Params(this);
  }
}

export class OwnershipChanged__Params {
  _event: OwnershipChanged;

  constructor(event: OwnershipChanged) {
    this._event = event;
  }

  get oldOwner(): Address {
    return this._event.parameters[0].value.toAddress();
  }

  get newOwner(): Address {
    return this._event.parameters[1].value.toAddress();
  }
}

export class TokenFactory__getMarketDetailsByIDResultValue0Struct extends ethereum.Tuple {
  get exists(): boolean {
    return this[0].toBoolean();
  }

  get id(): BigInt {
    return this[1].toBigInt();
  }

  get name(): string {
    return this[2].toString();
  }

  get numTokens(): BigInt {
    return this[3].toBigInt();
  }

  get baseCost(): BigInt {
    return this[4].toBigInt();
  }

  get priceRise(): BigInt {
    return this[5].toBigInt();
  }

  get hatchTokens(): BigInt {
    return this[6].toBigInt();
  }

  get tradingFeeRate(): BigInt {
    return this[7].toBigInt();
  }

  get platformFeeRate(): BigInt {
    return this[8].toBigInt();
  }

  get allInterestToPlatform(): boolean {
    return this[9].toBoolean();
  }
}

export class TokenFactory__getMarketDetailsByNameResultValue0Struct extends ethereum.Tuple {
  get exists(): boolean {
    return this[0].toBoolean();
  }

  get id(): BigInt {
    return this[1].toBigInt();
  }

  get name(): string {
    return this[2].toString();
  }

  get numTokens(): BigInt {
    return this[3].toBigInt();
  }

  get baseCost(): BigInt {
    return this[4].toBigInt();
  }

  get priceRise(): BigInt {
    return this[5].toBigInt();
  }

  get hatchTokens(): BigInt {
    return this[6].toBigInt();
  }

  get tradingFeeRate(): BigInt {
    return this[7].toBigInt();
  }

  get platformFeeRate(): BigInt {
    return this[8].toBigInt();
  }

  get allInterestToPlatform(): boolean {
    return this[9].toBoolean();
  }
}

export class TokenFactory__getMarketDetailsByTokenAddressResultValue0Struct extends ethereum.Tuple {
  get exists(): boolean {
    return this[0].toBoolean();
  }

  get id(): BigInt {
    return this[1].toBigInt();
  }

  get name(): string {
    return this[2].toString();
  }

  get numTokens(): BigInt {
    return this[3].toBigInt();
  }

  get baseCost(): BigInt {
    return this[4].toBigInt();
  }

  get priceRise(): BigInt {
    return this[5].toBigInt();
  }

  get hatchTokens(): BigInt {
    return this[6].toBigInt();
  }

  get tradingFeeRate(): BigInt {
    return this[7].toBigInt();
  }

  get platformFeeRate(): BigInt {
    return this[8].toBigInt();
  }

  get allInterestToPlatform(): boolean {
    return this[9].toBoolean();
  }
}

export class TokenFactory__getTokenIDPairResultValue0Struct extends ethereum.Tuple {
  get exists(): boolean {
    return this[0].toBoolean();
  }

  get marketID(): BigInt {
    return this[1].toBigInt();
  }

  get tokenID(): BigInt {
    return this[2].toBigInt();
  }
}

export class TokenFactory__getTokenInfoResultValue0Struct extends ethereum.Tuple {
  get exists(): boolean {
    return this[0].toBoolean();
  }

  get id(): BigInt {
    return this[1].toBigInt();
  }

  get name(): string {
    return this[2].toString();
  }

  get serviceToken(): Address {
    return this[3].toAddress();
  }
}

export class TokenFactory extends ethereum.SmartContract {
  static bind(address: Address): TokenFactory {
    return new TokenFactory("TokenFactory", address);
  }

  addMarket(
    marketName: string,
    baseCost: BigInt,
    priceRise: BigInt,
    hatchTokens: BigInt,
    tradingFeeRate: BigInt,
    platformFeeRate: BigInt,
    allInterestToPlatform: boolean
  ): BigInt {
    let result = super.call(
      "addMarket",
      "addMarket(string,uint256,uint256,uint256,uint256,uint256,bool):(uint256)",
      [
        ethereum.Value.fromString(marketName),
        ethereum.Value.fromUnsignedBigInt(baseCost),
        ethereum.Value.fromUnsignedBigInt(priceRise),
        ethereum.Value.fromUnsignedBigInt(hatchTokens),
        ethereum.Value.fromUnsignedBigInt(tradingFeeRate),
        ethereum.Value.fromUnsignedBigInt(platformFeeRate),
        ethereum.Value.fromBoolean(allInterestToPlatform)
      ]
    );

    return result[0].toBigInt();
  }

  try_addMarket(
    marketName: string,
    baseCost: BigInt,
    priceRise: BigInt,
    hatchTokens: BigInt,
    tradingFeeRate: BigInt,
    platformFeeRate: BigInt,
    allInterestToPlatform: boolean
  ): ethereum.CallResult<BigInt> {
    let result = super.tryCall(
      "addMarket",
      "addMarket(string,uint256,uint256,uint256,uint256,uint256,bool):(uint256)",
      [
        ethereum.Value.fromString(marketName),
        ethereum.Value.fromUnsignedBigInt(baseCost),
        ethereum.Value.fromUnsignedBigInt(priceRise),
        ethereum.Value.fromUnsignedBigInt(hatchTokens),
        ethereum.Value.fromUnsignedBigInt(tradingFeeRate),
        ethereum.Value.fromUnsignedBigInt(platformFeeRate),
        ethereum.Value.fromBoolean(allInterestToPlatform)
      ]
    );
    if (result.reverted) {
      return new ethereum.CallResult();
    }
    let value = result.value;
    return ethereum.CallResult.fromValue(value[0].toBigInt());
  }

  addToken(tokenName: string, marketID: BigInt, lister: Address): BigInt {
    let result = super.call(
      "addToken",
      "addToken(string,uint256,address):(uint256)",
      [
        ethereum.Value.fromString(tokenName),
        ethereum.Value.fromUnsignedBigInt(marketID),
        ethereum.Value.fromAddress(lister)
      ]
    );

    return result[0].toBigInt();
  }

  try_addToken(
    tokenName: string,
    marketID: BigInt,
    lister: Address
  ): ethereum.CallResult<BigInt> {
    let result = super.tryCall(
      "addToken",
      "addToken(string,uint256,address):(uint256)",
      [
        ethereum.Value.fromString(tokenName),
        ethereum.Value.fromUnsignedBigInt(marketID),
        ethereum.Value.fromAddress(lister)
      ]
    );
    if (result.reverted) {
      return new ethereum.CallResult();
    }
    let value = result.value;
    return ethereum.CallResult.fromValue(value[0].toBigInt());
  }

  getMarketDetailsByID(
    marketID: BigInt
  ): TokenFactory__getMarketDetailsByIDResultValue0Struct {
    let result = super.call(
      "getMarketDetailsByID",
      "getMarketDetailsByID(uint256):((bool,uint256,string,uint256,uint256,uint256,uint256,uint256,uint256,bool))",
      [ethereum.Value.fromUnsignedBigInt(marketID)]
    );

    return changetype<TokenFactory__getMarketDetailsByIDResultValue0Struct>(
      result[0].toTuple()
    );
  }

  try_getMarketDetailsByID(
    marketID: BigInt
  ): ethereum.CallResult<TokenFactory__getMarketDetailsByIDResultValue0Struct> {
    let result = super.tryCall(
      "getMarketDetailsByID",
      "getMarketDetailsByID(uint256):((bool,uint256,string,uint256,uint256,uint256,uint256,uint256,uint256,bool))",
      [ethereum.Value.fromUnsignedBigInt(marketID)]
    );
    if (result.reverted) {
      return new ethereum.CallResult();
    }
    let value = result.value;
    return ethereum.CallResult.fromValue(
      changetype<TokenFactory__getMarketDetailsByIDResultValue0Struct>(
        value[0].toTuple()
      )
    );
  }

  getMarketDetailsByName(
    marketName: string
  ): TokenFactory__getMarketDetailsByNameResultValue0Struct {
    let result = super.call(
      "getMarketDetailsByName",
      "getMarketDetailsByName(string):((bool,uint256,string,uint256,uint256,uint256,uint256,uint256,uint256,bool))",
      [ethereum.Value.fromString(marketName)]
    );

    return changetype<TokenFactory__getMarketDetailsByNameResultValue0Struct>(
      result[0].toTuple()
    );
  }

  try_getMarketDetailsByName(
    marketName: string
  ): ethereum.CallResult<
    TokenFactory__getMarketDetailsByNameResultValue0Struct
  > {
    let result = super.tryCall(
      "getMarketDetailsByName",
      "getMarketDetailsByName(string):((bool,uint256,string,uint256,uint256,uint256,uint256,uint256,uint256,bool))",
      [ethereum.Value.fromString(marketName)]
    );
    if (result.reverted) {
      return new ethereum.CallResult();
    }
    let value = result.value;
    return ethereum.CallResult.fromValue(
      changetype<TokenFactory__getMarketDetailsByNameResultValue0Struct>(
        value[0].toTuple()
      )
    );
  }

  getMarketDetailsByTokenAddress(
    serviceToken: Address
  ): TokenFactory__getMarketDetailsByTokenAddressResultValue0Struct {
    let result = super.call(
      "getMarketDetailsByTokenAddress",
      "getMarketDetailsByTokenAddress(address):((bool,uint256,string,uint256,uint256,uint256,uint256,uint256,uint256,bool))",
      [ethereum.Value.fromAddress(serviceToken)]
    );

    return changetype<
      TokenFactory__getMarketDetailsByTokenAddressResultValue0Struct
    >(result[0].toTuple());
  }

  try_getMarketDetailsByTokenAddress(
    serviceToken: Address
  ): ethereum.CallResult<
    TokenFactory__getMarketDetailsByTokenAddressResultValue0Struct
  > {
    let result = super.tryCall(
      "getMarketDetailsByTokenAddress",
      "getMarketDetailsByTokenAddress(address):((bool,uint256,string,uint256,uint256,uint256,uint256,uint256,uint256,bool))",
      [ethereum.Value.fromAddress(serviceToken)]
    );
    if (result.reverted) {
      return new ethereum.CallResult();
    }
    let value = result.value;
    return ethereum.CallResult.fromValue(
      changetype<
        TokenFactory__getMarketDetailsByTokenAddressResultValue0Struct
      >(value[0].toTuple())
    );
  }

  getMarketIDByName(marketName: string): BigInt {
    let result = super.call(
      "getMarketIDByName",
      "getMarketIDByName(string):(uint256)",
      [ethereum.Value.fromString(marketName)]
    );

    return result[0].toBigInt();
  }

  try_getMarketIDByName(marketName: string): ethereum.CallResult<BigInt> {
    let result = super.tryCall(
      "getMarketIDByName",
      "getMarketIDByName(string):(uint256)",
      [ethereum.Value.fromString(marketName)]
    );
    if (result.reverted) {
      return new ethereum.CallResult();
    }
    let value = result.value;
    return ethereum.CallResult.fromValue(value[0].toBigInt());
  }

  getMarketIDByTokenAddress(tokenAddress: Address): BigInt {
    let result = super.call(
      "getMarketIDByTokenAddress",
      "getMarketIDByTokenAddress(address):(uint256)",
      [ethereum.Value.fromAddress(tokenAddress)]
    );

    return result[0].toBigInt();
  }

  try_getMarketIDByTokenAddress(
    tokenAddress: Address
  ): ethereum.CallResult<BigInt> {
    let result = super.tryCall(
      "getMarketIDByTokenAddress",
      "getMarketIDByTokenAddress(address):(uint256)",
      [ethereum.Value.fromAddress(tokenAddress)]
    );
    if (result.reverted) {
      return new ethereum.CallResult();
    }
    let value = result.value;
    return ethereum.CallResult.fromValue(value[0].toBigInt());
  }

  getNumMarkets(): BigInt {
    let result = super.call("getNumMarkets", "getNumMarkets():(uint256)", []);

    return result[0].toBigInt();
  }

  try_getNumMarkets(): ethereum.CallResult<BigInt> {
    let result = super.tryCall(
      "getNumMarkets",
      "getNumMarkets():(uint256)",
      []
    );
    if (result.reverted) {
      return new ethereum.CallResult();
    }
    let value = result.value;
    return ethereum.CallResult.fromValue(value[0].toBigInt());
  }

  getOwner(): Address {
    let result = super.call("getOwner", "getOwner():(address)", []);

    return result[0].toAddress();
  }

  try_getOwner(): ethereum.CallResult<Address> {
    let result = super.tryCall("getOwner", "getOwner():(address)", []);
    if (result.reverted) {
      return new ethereum.CallResult();
    }
    let value = result.value;
    return ethereum.CallResult.fromValue(value[0].toAddress());
  }

  getTokenIDByName(tokenName: string, marketID: BigInt): BigInt {
    let result = super.call(
      "getTokenIDByName",
      "getTokenIDByName(string,uint256):(uint256)",
      [
        ethereum.Value.fromString(tokenName),
        ethereum.Value.fromUnsignedBigInt(marketID)
      ]
    );

    return result[0].toBigInt();
  }

  try_getTokenIDByName(
    tokenName: string,
    marketID: BigInt
  ): ethereum.CallResult<BigInt> {
    let result = super.tryCall(
      "getTokenIDByName",
      "getTokenIDByName(string,uint256):(uint256)",
      [
        ethereum.Value.fromString(tokenName),
        ethereum.Value.fromUnsignedBigInt(marketID)
      ]
    );
    if (result.reverted) {
      return new ethereum.CallResult();
    }
    let value = result.value;
    return ethereum.CallResult.fromValue(value[0].toBigInt());
  }

  getTokenIDPair(
    token: Address
  ): TokenFactory__getTokenIDPairResultValue0Struct {
    let result = super.call(
      "getTokenIDPair",
      "getTokenIDPair(address):((bool,uint256,uint256))",
      [ethereum.Value.fromAddress(token)]
    );

    return changetype<TokenFactory__getTokenIDPairResultValue0Struct>(
      result[0].toTuple()
    );
  }

  try_getTokenIDPair(
    token: Address
  ): ethereum.CallResult<TokenFactory__getTokenIDPairResultValue0Struct> {
    let result = super.tryCall(
      "getTokenIDPair",
      "getTokenIDPair(address):((bool,uint256,uint256))",
      [ethereum.Value.fromAddress(token)]
    );
    if (result.reverted) {
      return new ethereum.CallResult();
    }
    let value = result.value;
    return ethereum.CallResult.fromValue(
      changetype<TokenFactory__getTokenIDPairResultValue0Struct>(
        value[0].toTuple()
      )
    );
  }

  getTokenInfo(
    marketID: BigInt,
    tokenID: BigInt
  ): TokenFactory__getTokenInfoResultValue0Struct {
    let result = super.call(
      "getTokenInfo",
      "getTokenInfo(uint256,uint256):((bool,uint256,string,address))",
      [
        ethereum.Value.fromUnsignedBigInt(marketID),
        ethereum.Value.fromUnsignedBigInt(tokenID)
      ]
    );

    return changetype<TokenFactory__getTokenInfoResultValue0Struct>(
      result[0].toTuple()
    );
  }

  try_getTokenInfo(
    marketID: BigInt,
    tokenID: BigInt
  ): ethereum.CallResult<TokenFactory__getTokenInfoResultValue0Struct> {
    let result = super.tryCall(
      "getTokenInfo",
      "getTokenInfo(uint256,uint256):((bool,uint256,string,address))",
      [
        ethereum.Value.fromUnsignedBigInt(marketID),
        ethereum.Value.fromUnsignedBigInt(tokenID)
      ]
    );
    if (result.reverted) {
      return new ethereum.CallResult();
    }
    let value = result.value;
    return ethereum.CallResult.fromValue(
      changetype<TokenFactory__getTokenInfoResultValue0Struct>(
        value[0].toTuple()
      )
    );
  }

  isValidTokenName(tokenName: string, marketID: BigInt): boolean {
    let result = super.call(
      "isValidTokenName",
      "isValidTokenName(string,uint256):(bool)",
      [
        ethereum.Value.fromString(tokenName),
        ethereum.Value.fromUnsignedBigInt(marketID)
      ]
    );

    return result[0].toBoolean();
  }

  try_isValidTokenName(
    tokenName: string,
    marketID: BigInt
  ): ethereum.CallResult<boolean> {
    let result = super.tryCall(
      "isValidTokenName",
      "isValidTokenName(string,uint256):(bool)",
      [
        ethereum.Value.fromString(tokenName),
        ethereum.Value.fromUnsignedBigInt(marketID)
      ]
    );
    if (result.reverted) {
      return new ethereum.CallResult();
    }
    let value = result.value;
    return ethereum.CallResult.fromValue(value[0].toBoolean());
  }
}

export class AddMarketCall extends ethereum.Call {
  get inputs(): AddMarketCall__Inputs {
    return new AddMarketCall__Inputs(this);
  }

  get outputs(): AddMarketCall__Outputs {
    return new AddMarketCall__Outputs(this);
  }
}

export class AddMarketCall__Inputs {
  _call: AddMarketCall;

  constructor(call: AddMarketCall) {
    this._call = call;
  }

  get marketName(): string {
    return this._call.inputValues[0].value.toString();
  }

  get baseCost(): BigInt {
    return this._call.inputValues[1].value.toBigInt();
  }

  get priceRise(): BigInt {
    return this._call.inputValues[2].value.toBigInt();
  }

  get hatchTokens(): BigInt {
    return this._call.inputValues[3].value.toBigInt();
  }

  get tradingFeeRate(): BigInt {
    return this._call.inputValues[4].value.toBigInt();
  }

  get platformFeeRate(): BigInt {
    return this._call.inputValues[5].value.toBigInt();
  }

  get allInterestToPlatform(): boolean {
    return this._call.inputValues[6].value.toBoolean();
  }
}

export class AddMarketCall__Outputs {
  _call: AddMarketCall;

  constructor(call: AddMarketCall) {
    this._call = call;
  }

  get value0(): BigInt {
    return this._call.outputValues[0].value.toBigInt();
  }
}

export class AddTokenCall extends ethereum.Call {
  get inputs(): AddTokenCall__Inputs {
    return new AddTokenCall__Inputs(this);
  }

  get outputs(): AddTokenCall__Outputs {
    return new AddTokenCall__Outputs(this);
  }
}

export class AddTokenCall__Inputs {
  _call: AddTokenCall;

  constructor(call: AddTokenCall) {
    this._call = call;
  }

  get tokenName(): string {
    return this._call.inputValues[0].value.toString();
  }

  get marketID(): BigInt {
    return this._call.inputValues[1].value.toBigInt();
  }

  get lister(): Address {
    return this._call.inputValues[2].value.toAddress();
  }
}

export class AddTokenCall__Outputs {
  _call: AddTokenCall;

  constructor(call: AddTokenCall) {
    this._call = call;
  }

  get value0(): BigInt {
    return this._call.outputValues[0].value.toBigInt();
  }
}

export class InitializeCall extends ethereum.Call {
  get inputs(): InitializeCall__Inputs {
    return new InitializeCall__Inputs(this);
  }

  get outputs(): InitializeCall__Outputs {
    return new InitializeCall__Outputs(this);
  }
}

export class InitializeCall__Inputs {
  _call: InitializeCall;

  constructor(call: InitializeCall) {
    this._call = call;
  }

  get owner(): Address {
    return this._call.inputValues[0].value.toAddress();
  }

  get tokenExchange(): Address {
    return this._call.inputValues[1].value.toAddress();
  }

  get tokenLogic(): Address {
    return this._call.inputValues[2].value.toAddress();
  }

  get networkManager(): Address {
    return this._call.inputValues[3].value.toAddress();
  }
}

export class InitializeCall__Outputs {
  _call: InitializeCall;

  constructor(call: InitializeCall) {
    this._call = call;
  }
}

export class SetOwnerCall extends ethereum.Call {
  get inputs(): SetOwnerCall__Inputs {
    return new SetOwnerCall__Inputs(this);
  }

  get outputs(): SetOwnerCall__Outputs {
    return new SetOwnerCall__Outputs(this);
  }
}

export class SetOwnerCall__Inputs {
  _call: SetOwnerCall;

  constructor(call: SetOwnerCall) {
    this._call = call;
  }

  get newOwner(): Address {
    return this._call.inputValues[0].value.toAddress();
  }
}

export class SetOwnerCall__Outputs {
  _call: SetOwnerCall;

  constructor(call: SetOwnerCall) {
    this._call = call;
  }
}

export class SetPlatformFeeCall extends ethereum.Call {
  get inputs(): SetPlatformFeeCall__Inputs {
    return new SetPlatformFeeCall__Inputs(this);
  }

  get outputs(): SetPlatformFeeCall__Outputs {
    return new SetPlatformFeeCall__Outputs(this);
  }
}

export class SetPlatformFeeCall__Inputs {
  _call: SetPlatformFeeCall;

  constructor(call: SetPlatformFeeCall) {
    this._call = call;
  }

  get marketID(): BigInt {
    return this._call.inputValues[0].value.toBigInt();
  }

  get platformFeeRate(): BigInt {
    return this._call.inputValues[1].value.toBigInt();
  }
}

export class SetPlatformFeeCall__Outputs {
  _call: SetPlatformFeeCall;

  constructor(call: SetPlatformFeeCall) {
    this._call = call;
  }
}

export class SetTradingFeeCall extends ethereum.Call {
  get inputs(): SetTradingFeeCall__Inputs {
    return new SetTradingFeeCall__Inputs(this);
  }

  get outputs(): SetTradingFeeCall__Outputs {
    return new SetTradingFeeCall__Outputs(this);
  }
}

export class SetTradingFeeCall__Inputs {
  _call: SetTradingFeeCall;

  constructor(call: SetTradingFeeCall) {
    this._call = call;
  }

  get marketID(): BigInt {
    return this._call.inputValues[0].value.toBigInt();
  }

  get tradingFeeRate(): BigInt {
    return this._call.inputValues[1].value.toBigInt();
  }
}

export class SetTradingFeeCall__Outputs {
  _call: SetTradingFeeCall;

  constructor(call: SetTradingFeeCall) {
    this._call = call;
  }
}