library NetworkInterface {
    struct Relationship {
        address valuePtr;
        uint256 id;
        uint256 marketPtr;
        address employer;
        address worker;
        string taskMetadataPtr;
        ContractStatus contractStatus;
        ContractOwnership contractOwnership;
        ContractPayoutType contractPayoutType;
        uint256 wad;
        uint256 acceptanceTimestamp;
        uint256 resolutionTimestamp;
        uint256 satisfactoryScore;
        string solutionMetadataPtr;
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
        uint256 valuePtr;
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
        uint256 MAX_WAITLIST_SIZE;
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
        Pending,
        Claimed
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
}