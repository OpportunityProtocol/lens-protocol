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

    struct Market {
        string marketName;
        uint256 marketID;
        uint256[] relationships;
        address valuePtr;
    }

    struct UserSummary {
        uint256 lensProfileID;
        uint256 registrationTimestamp;
        address trueIdentification;
        bool isRegistered;
        uint256 referenceFee;
    }

    struct RelationshipEscrowDetails {
        EscrowStatus status;
        uint256 disputeID;
        uint256 createdAt;
        uint256 reclaimedAt;
        uint256 payerFeeDeposit;
        uint256 payeeFeeDeposit;
    }

    struct Service {
        uint256 marketId;
        address owner;
        string metadataPtr;
        uint256 wad;
        uint256 referralShare;
        bool exist;
        uint256 id;
        address collectModule;
    }

    enum RulingOptions {
        PayerWins,
        PayeeWins
    }

    enum EscrowStatus {
        Initial,
        Reclaimed,
        Disputed,
        Resolved
    }

    enum Persona {
        Employer,
        Worker
    }

    /**
     * @dev Enum representing the states ownership for a relationship
     */
    enum ContractOwnership {
        Unclaimed,
        Claimed,
        Resolved,
        Reclaimed,
        Disputed
    }

    /**
     * @dev Enum representing the states ownership for a relationship
     */
    enum ContractStatus {
        AwaitingWorker,
        AwaitingWorkerApproval,
        AwaitingResolution,
        Resolved,
        PendingDispute,
        Disputed
    }

    enum ContractPayoutType {
        Flat,
        Milestone
    }

    struct PurchasedServiceMetadata {
        uint256 purchaseId;
        address client;
        bool exist;
        uint256 timestampPurchased;
        address referral;
    }
}