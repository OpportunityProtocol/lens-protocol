// THIS IS AN AUTOGENERATED FILE. DO NOT EDIT THIS FILE DIRECTLY.

import {
  TypedMap,
  Entity,
  Value,
  ValueKind,
  store,
  Bytes,
  BigInt,
  BigDecimal
} from "@graphprotocol/graph-ts";

export class ExampleEntity extends Entity {
  constructor(id: string) {
    super();
    this.set("id", Value.fromString(id));
  }

  save(): void {
    let id = this.get("id");
    assert(id != null, "Cannot save ExampleEntity entity without an ID");
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type ExampleEntity must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set("ExampleEntity", id.toString(), this);
    }
  }

  static load(id: string): ExampleEntity | null {
    return changetype<ExampleEntity | null>(store.get("ExampleEntity", id));
  }

  get id(): string {
    let value = this.get("id");
    return value!.toString();
  }

  set id(value: string) {
    this.set("id", Value.fromString(value));
  }

  get count(): BigInt {
    let value = this.get("count");
    return value!.toBigInt();
  }

  set count(value: BigInt) {
    this.set("count", Value.fromBigInt(value));
  }

  get fee(): i32 {
    let value = this.get("fee");
    return value!.toI32();
  }

  set fee(value: i32) {
    this.set("fee", Value.fromI32(value));
  }

  get tickSpacing(): i32 {
    let value = this.get("tickSpacing");
    return value!.toI32();
  }

  set tickSpacing(value: i32) {
    this.set("tickSpacing", Value.fromI32(value));
  }
}

export class VerifiedUser extends Entity {
  constructor(id: string) {
    super();
    this.set("id", Value.fromString(id));
  }

  save(): void {
    let id = this.get("id");
    assert(id != null, "Cannot save VerifiedUser entity without an ID");
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type VerifiedUser must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set("VerifiedUser", id.toString(), this);
    }
  }

  static load(id: string): VerifiedUser | null {
    return changetype<VerifiedUser | null>(store.get("VerifiedUser", id));
  }

  get id(): string {
    let value = this.get("id");
    return value!.toString();
  }

  set id(value: string) {
    this.set("id", Value.fromString(value));
  }

  get address(): Bytes {
    let value = this.get("address");
    return value!.toBytes();
  }

  set address(value: Bytes) {
    this.set("address", Value.fromBytes(value));
  }

  get handle(): string {
    let value = this.get("handle");
    return value!.toString();
  }

  set handle(value: string) {
    this.set("handle", Value.fromString(value));
  }

  get imageURI(): string {
    let value = this.get("imageURI");
    return value!.toString();
  }

  set imageURI(value: string) {
    this.set("imageURI", Value.fromString(value));
  }

  get metadata(): string {
    let value = this.get("metadata");
    return value!.toString();
  }

  set metadata(value: string) {
    this.set("metadata", Value.fromString(value));
  }
}

export class Service extends Entity {
  constructor(id: string) {
    super();
    this.set("id", Value.fromString(id));
  }

  save(): void {
    let id = this.get("id");
    assert(id != null, "Cannot save Service entity without an ID");
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type Service must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set("Service", id.toString(), this);
    }
  }

  static load(id: string): Service | null {
    return changetype<Service | null>(store.get("Service", id));
  }

  get id(): string {
    let value = this.get("id");
    return value!.toString();
  }

  set id(value: string) {
    this.set("id", Value.fromString(value));
  }

  get marketId(): BigInt {
    let value = this.get("marketId");
    return value!.toBigInt();
  }

  set marketId(value: BigInt) {
    this.set("marketId", Value.fromBigInt(value));
  }

  get creator(): Bytes {
    let value = this.get("creator");
    return value!.toBytes();
  }

  set creator(value: Bytes) {
    this.set("creator", Value.fromBytes(value));
  }

  get metadataPtr(): string {
    let value = this.get("metadataPtr");
    return value!.toString();
  }

  set metadataPtr(value: string) {
    this.set("metadataPtr", Value.fromString(value));
  }

  get pubId(): BigInt {
    let value = this.get("pubId");
    return value!.toBigInt();
  }

  set pubId(value: BigInt) {
    this.set("pubId", Value.fromBigInt(value));
  }

  get offers(): Array<BigInt> | null {
    let value = this.get("offers");
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigIntArray();
    }
  }

  set offers(value: Array<BigInt> | null) {
    if (!value) {
      this.unset("offers");
    } else {
      this.set("offers", Value.fromBigIntArray(<Array<BigInt>>value));
    }
  }
}

export class PurchasedService extends Entity {
  constructor(id: string) {
    super();
    this.set("id", Value.fromString(id));
  }

  save(): void {
    let id = this.get("id");
    assert(id != null, "Cannot save PurchasedService entity without an ID");
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type PurchasedService must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set("PurchasedService", id.toString(), this);
    }
  }

  static load(id: string): PurchasedService | null {
    return changetype<PurchasedService | null>(
      store.get("PurchasedService", id)
    );
  }

  get id(): string {
    let value = this.get("id");
    return value!.toString();
  }

  set id(value: string) {
    this.set("id", Value.fromString(value));
  }

  get creator(): Bytes {
    let value = this.get("creator");
    return value!.toBytes();
  }

  set creator(value: Bytes) {
    this.set("creator", Value.fromBytes(value));
  }

  get client(): Bytes {
    let value = this.get("client");
    return value!.toBytes();
  }

  set client(value: Bytes) {
    this.set("client", Value.fromBytes(value));
  }

  get datePurchased(): BigInt {
    let value = this.get("datePurchased");
    return value!.toBigInt();
  }

  set datePurchased(value: BigInt) {
    this.set("datePurchased", Value.fromBigInt(value));
  }

  get purchaseId(): BigInt {
    let value = this.get("purchaseId");
    return value!.toBigInt();
  }

  set purchaseId(value: BigInt) {
    this.set("purchaseId", Value.fromBigInt(value));
  }

  get metadata(): string {
    let value = this.get("metadata");
    return value!.toString();
  }

  set metadata(value: string) {
    this.set("metadata", Value.fromString(value));
  }

  get offer(): BigInt {
    let value = this.get("offer");
    return value!.toBigInt();
  }

  set offer(value: BigInt) {
    this.set("offer", Value.fromBigInt(value));
  }

  get status(): i32 {
    let value = this.get("status");
    return value!.toI32();
  }

  set status(value: i32) {
    this.set("status", Value.fromI32(value));
  }

  get pubId(): BigInt {
    let value = this.get("pubId");
    return value!.toBigInt();
  }

  set pubId(value: BigInt) {
    this.set("pubId", Value.fromBigInt(value));
  }

  get serviceId(): BigInt {
    let value = this.get("serviceId");
    return value!.toBigInt();
  }

  set serviceId(value: BigInt) {
    this.set("serviceId", Value.fromBigInt(value));
  }
}

export class Contract extends Entity {
  constructor(id: string) {
    super();
    this.set("id", Value.fromString(id));
  }

  save(): void {
    let id = this.get("id");
    assert(id != null, "Cannot save Contract entity without an ID");
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type Contract must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set("Contract", id.toString(), this);
    }
  }

  static load(id: string): Contract | null {
    return changetype<Contract | null>(store.get("Contract", id));
  }

  get id(): string {
    let value = this.get("id");
    return value!.toString();
  }

  set id(value: string) {
    this.set("id", Value.fromString(value));
  }

  get employer(): Bytes {
    let value = this.get("employer");
    return value!.toBytes();
  }

  set employer(value: Bytes) {
    this.set("employer", Value.fromBytes(value));
  }

  get marketId(): BigInt {
    let value = this.get("marketId");
    return value!.toBigInt();
  }

  set marketId(value: BigInt) {
    this.set("marketId", Value.fromBigInt(value));
  }

  get metadata(): string {
    let value = this.get("metadata");
    return value!.toString();
  }

  set metadata(value: string) {
    this.set("metadata", Value.fromString(value));
  }

  get worker(): Bytes {
    let value = this.get("worker");
    return value!.toBytes();
  }

  set worker(value: Bytes) {
    this.set("worker", Value.fromBytes(value));
  }

  get ownership(): i32 {
    let value = this.get("ownership");
    return value!.toI32();
  }

  set ownership(value: i32) {
    this.set("ownership", Value.fromI32(value));
  }

  get acceptanceTimestamp(): string {
    let value = this.get("acceptanceTimestamp");
    return value!.toString();
  }

  set acceptanceTimestamp(value: string) {
    this.set("acceptanceTimestamp", Value.fromString(value));
  }

  get resolutionTimestamp(): string {
    let value = this.get("resolutionTimestamp");
    return value!.toString();
  }

  set resolutionTimestamp(value: string) {
    this.set("resolutionTimestamp", Value.fromString(value));
  }

  get amount(): BigInt {
    let value = this.get("amount");
    return value!.toBigInt();
  }

  set amount(value: BigInt) {
    this.set("amount", Value.fromBigInt(value));
  }

  get dateCreated(): string {
    let value = this.get("dateCreated");
    return value!.toString();
  }

  set dateCreated(value: string) {
    this.set("dateCreated", Value.fromString(value));
  }
}

export class ServiceToken extends Entity {
  constructor(id: string) {
    super();
    this.set("id", Value.fromString(id));
  }

  save(): void {
    let id = this.get("id");
    assert(id != null, "Cannot save ServiceToken entity without an ID");
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type ServiceToken must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set("ServiceToken", id.toString(), this);
    }
  }

  static load(id: string): ServiceToken | null {
    return changetype<ServiceToken | null>(store.get("ServiceToken", id));
  }

  get id(): string {
    let value = this.get("id");
    return value!.toString();
  }

  set id(value: string) {
    this.set("id", Value.fromString(value));
  }

  get marketID(): BigInt {
    let value = this.get("marketID");
    return value!.toBigInt();
  }

  set marketID(value: BigInt) {
    this.set("marketID", Value.fromBigInt(value));
  }

  get name(): string {
    let value = this.get("name");
    return value!.toString();
  }

  set name(value: string) {
    this.set("name", Value.fromString(value));
  }

  get address(): Bytes {
    let value = this.get("address");
    return value!.toBytes();
  }

  set address(value: Bytes) {
    this.set("address", Value.fromBytes(value));
  }

  get lister(): Bytes {
    let value = this.get("lister");
    return value!.toBytes();
  }

  set lister(value: Bytes) {
    this.set("lister", Value.fromBytes(value));
  }
}

export class Market extends Entity {
  constructor(id: string) {
    super();
    this.set("id", Value.fromString(id));
  }

  save(): void {
    let id = this.get("id");
    assert(id != null, "Cannot save Market entity without an ID");
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type Market must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set("Market", id.toString(), this);
    }
  }

  static load(id: string): Market | null {
    return changetype<Market | null>(store.get("Market", id));
  }

  get id(): string {
    let value = this.get("id");
    return value!.toString();
  }

  set id(value: string) {
    this.set("id", Value.fromString(value));
  }

  get name(): string {
    let value = this.get("name");
    return value!.toString();
  }

  set name(value: string) {
    this.set("name", Value.fromString(value));
  }

  get baseCost(): BigInt {
    let value = this.get("baseCost");
    return value!.toBigInt();
  }

  set baseCost(value: BigInt) {
    this.set("baseCost", Value.fromBigInt(value));
  }

  get priceRise(): BigInt {
    let value = this.get("priceRise");
    return value!.toBigInt();
  }

  set priceRise(value: BigInt) {
    this.set("priceRise", Value.fromBigInt(value));
  }

  get hatchTokens(): BigInt {
    let value = this.get("hatchTokens");
    return value!.toBigInt();
  }

  set hatchTokens(value: BigInt) {
    this.set("hatchTokens", Value.fromBigInt(value));
  }

  get tradingFeeRate(): BigInt {
    let value = this.get("tradingFeeRate");
    return value!.toBigInt();
  }

  set tradingFeeRate(value: BigInt) {
    this.set("tradingFeeRate", Value.fromBigInt(value));
  }

  get platformFeeRate(): BigInt {
    let value = this.get("platformFeeRate");
    return value!.toBigInt();
  }

  set platformFeeRate(value: BigInt) {
    this.set("platformFeeRate", Value.fromBigInt(value));
  }

  get allInterestToPlatform(): boolean {
    let value = this.get("allInterestToPlatform");
    return value!.toBoolean();
  }

  set allInterestToPlatform(value: boolean) {
    this.set("allInterestToPlatform", Value.fromBoolean(value));
  }
}

export class TokenInfo extends Entity {
  constructor(id: string) {
    super();
    this.set("id", Value.fromString(id));
  }

  save(): void {
    let id = this.get("id");
    assert(id != null, "Cannot save TokenInfo entity without an ID");
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type TokenInfo must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set("TokenInfo", id.toString(), this);
    }
  }

  static load(id: string): TokenInfo | null {
    return changetype<TokenInfo | null>(store.get("TokenInfo", id));
  }

  get id(): string {
    let value = this.get("id");
    return value!.toString();
  }

  set id(value: string) {
    this.set("id", Value.fromString(value));
  }
}
