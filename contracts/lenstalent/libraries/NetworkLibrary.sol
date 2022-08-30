library NetworkLibrary {
    error InvalidStatus();
    error ReleasedTooEarly();
    error NotPayer();
    error NotArbitrator();
    error ThirdPartyNotAllowed();
    error PayeeDepositStillPending();
    error ReclaimedTooLate();
    error InsufficientPayment(uint256 _available, uint256 _required);
    error InvalidRuling(uint256 _ruling, uint256 _numberOfChoices);

    // contract struct
    struct Relationship {
        address employer;
        address worker;
        string taskMetadataPtr;
        ContractOwnership contractOwnership;
        uint256 wad;
        uint256 acceptanceTimestamp;
        uint256 resolutionTimestamp;
        uint256 marketId;
    }

    //market struct
    struct Market {
        string marketName;
        uint256 marketID;
        uint256[] relationships;
        address valuePtr;
    }

    //contract escrow details struct
    struct RelationshipEscrowDetails {
        EscrowStatus status;
        uint256 disputeID;
        uint256 createdAt;
        uint256 reclaimedAt;
        uint256 payerFeeDeposit;
        uint256 payeeFeeDeposit;
    }

    //service struct
    struct Service {
        uint256 marketId;
        address creator;
        string metadataPtr;
        uint256[] offers;
        bool exist;
        uint256 id;
        address collectModule;
        address referenceModule;
        uint256 pubId;
    }

    // Enum representing the ruling options for disputes
    enum RulingOptions {
        PayerWins,
        PayeeWins
    }

    // Enum representing the escrow status for a contract and service
    enum EscrowStatus {
        Initial,
        Reclaimed,
        Disputed,
        Resolved
    }

    // Enum representing the states ownership for a relationship
    enum ContractOwnership {
        Unclaimed,
        Claimed,
        Resolved,
        Reclaimed,
        Disputed
    }

    // Enum representing the states ownership for a relationship
    enum ContractStatus {
        AwaitingWorker,
        AwaitingWorkerApproval,
        AwaitingResolution,
        Resolved,
        PendingDispute,
        Disputed
    }

    // Enum representing the possible states of a service
    enum ServiceResolutionStatus {
        PENDING,
        PENDING_DISPUTE,
        RESOLVED
    }

    // Enu representing the purchase metadata for a service
    struct PurchasedServiceMetadata {
        uint256 purchaseId;
        address client;
        address creator;
        bool exist;
        uint256 timestampPurchased;
        uint8 offer;
        ServiceResolutionStatus status;
    }
}
