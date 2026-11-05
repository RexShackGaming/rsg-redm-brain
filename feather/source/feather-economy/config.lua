Config = {
    Contract = 1,
    RequiredCoreContract = 1,
    -- Registers the data-changing console tests and the migration fault switch.
    -- Development servers only; keep false for production.
    DevMode = false,
    SystemOwnerId = '00000000-0000-0000-0000-000000000001',
    -- Resources allowed to call each group of exports (README "Access groups").
    -- Feather resources are active. Known consumers are listed under them,
    -- commented out: uncomment a resource's line in every group where it appears
    -- (and its OperatorSupply block), then restart feather-economy.
    --   feather-contracts  reconciles and settles obligations such as rent and tax
    --   bcc-banks          bank accounts, statements, branch reserves
    --   bcc-society        business treasuries: deposits, withdrawals, payroll, bills, tax
    --   bcc-stables        horse and tack purchases
    --   bcc-shops          store purchases
    --   bcc-craft          crafting book purchases
    --   bcc-housing        house purchases, rent, tax; sale back to the agent creates money
    Access = {
        trustedTreasuryProvisioners = {
            ['feather-economy'] = true,
            ['feather-shops'] = true,
            ['feather-admin'] = true,
        },
        -- Operated accounts (README "Operated accounts"). May provision character
        -- bank accounts (EnsureCharacterBankAccounts).
        trustedBankProvisioners = {
            ['feather-economy'] = true,
            ['bcc-banks'] = true,         -- one account per character and branch
        },
        -- May register reason codes whose shapes move character bank accounts.
        -- They must also be in trustedTransactors.
        trustedBankTransactors = {
            ['feather-economy'] = true,
            ['bcc-banks'] = true,         -- deposits, withdrawals, transfers, fees, loans, checks
        },
        -- May bind organization treasuries (EnsureOperatedTreasury) and register
        -- reason codes whose shapes move them. They must also be in trustedTransactors.
        trustedTreasuryOperators = {
            ['bcc-banks'] = true,         -- the reserve treasury of each branch
            ['bcc-society'] = true,       -- the treasury of each business
        },
        -- May read the journal history of any account (ListAccountEntries). Other
        -- trusted readers see only accounts they serve: bank transactors read bank
        -- accounts, treasury operators read the treasury bound to them.
        privilegedHistoryReaders = {
            ['feather-economy'] = true,
            ['feather-admin'] = true,
        },
        trustedReaders = {
            ['feather-economy'] = true,
            ['feather-admin'] = true,
            ['feather-hud'] = true,
            ['feather-shops'] = true,
            ['feather-contracts'] = true, -- reconciles settlements with GetTransaction
            ['bcc-banks'] = true,         -- balances and statements of bank accounts and reserves
            ['bcc-society'] = true,       -- treasury balance; the system sink for fees
            ['bcc-stables'] = true,       -- the system sink that purchases pay into
            ['bcc-shops'] = true,         -- the system sink that purchases pay into
            ['bcc-craft'] = true,         -- the system sink that book purchases pay into
            ['bcc-housing'] = true,       -- wallet balance before a purchase; the system sink
        },
        trustedProvisioners = {
            ['feather-economy'] = true,
            ['feather-character'] = true,
            ['feather-shops'] = true,
            ['feather-admin'] = true,
            ['bcc-banks'] = true,         -- the character's wallet for deposits and withdrawals
            ['bcc-society'] = true,       -- member wallets for deposits, withdrawals and wages
            ['bcc-stables'] = true,       -- the buyer's or seller's wallet
            ['bcc-shops'] = true,         -- the buyer's wallet
            ['bcc-craft'] = true,         -- the buyer's wallet
            ['bcc-housing'] = true,       -- the buyer's or tenant's wallet
        },
        trustedTransactors = {
            ['feather-economy'] = true,
            ['feather-shops'] = true,
            ['feather-contracts'] = true, -- settles obligations such as rent and tax
            ['bcc-banks'] = true,         -- bank.* reasons it registers (RegisterOperatedReasons)
            ['bcc-society'] = true,       -- society.* reasons it registers (RegisterOperatedReasons)
            ['bcc-stables'] = true,       -- horse, tack and taming purchases into the system sink
            ['bcc-shops'] = true,         -- store purchases into the system sink
            ['bcc-craft'] = true,         -- crafting book purchases into the system sink
            ['bcc-housing'] = true,       -- house purchases, rent and tax
        },
        -- May settle payable obligations (Config.Settlement): pay an obligation into
        -- an organization treasury, and out of one for the resource that operates it.
        trustedSettlers = {
            ['feather-contracts'] = true,
        },
        trustedReversers = {
            ['feather-economy'] = true,
            ['feather-shops'] = true,
            ['bcc-stables'] = true,
        },
        -- Issue and Destroy; each also needs the Core policy grant (Authorization).
        -- Stables uses the exact scoped IssueReasons below plus the Core service grant;
        -- do not add it here as an unrestricted currency supplier.
        trustedSuppliers = {
            ['feather-economy'] = true,
            ['feather-admin'] = true,
        },
    },
    -- Additional original-payment scopes; caller ownership is always required.
    -- Existing shop.purchase/shop_order reversal behavior remains supported.
    ReversiblePayments = {
        ['bcc-stables'] = {
            ['stables.horse_purchase'] = {
                referenceType = 'stables_order',
                reversalReason = 'stables.payment_reversal'
            },
            ['stables.tack_purchase'] = {
                referenceType = 'stables_order',
                reversalReason = 'stables.payment_reversal'
            },
            ['stables.tack_trade_payment'] = {
                referenceType = 'stables_tack_trade',
                reversalReason = 'stables.tack_trade_refund'
            },
            ['stables.horse_trade_payment'] = {
                referenceType = 'stables_horse_trade',
                reversalReason = 'stables.horse_trade_refund'
            },
        },
    },
    -- Reason codes a resource may create currency into a character wallet with
    -- (Issue), per resource, exact match only: NPC buy-backs, job pay, rewards.
    -- Such a resource cannot destroy currency or issue with any other reason, and
    -- each issue still needs a Core policy grant (economy.currency.issue).
    -- Add a resource's codes when it is ported.
    IssueReasons = {
        ['bcc-housing'] = {
            ['housing.sold_to_agent'] = true,    -- the housing agent buys a house back
            ['housing.furniture_sold'] = true    -- furniture sold back
        },
        ['bcc-stables'] = {
            ['stables.tack_trade_sale'] = true,  -- Settles an accepted player tack trade
            ['stables.horse_trade_sale'] = true, -- Settles an accepted player horse/package trade
            ['stables.tack_sale'] = true,        -- stable tack buy-back only
            ['stables.horse_sale'] = true,       -- the stable buys a horse
            ['stables.tamed_sale'] = true        -- a trainer buys a tamed horse
        },
    },
    -- Reason codes an operator may create currency with (issue_to_bank and
    -- issue_to_operated shapes), per resource, exact match only. Each issue still
    -- needs a Core policy grant (economy.currency.issue) for the resource.
    OperatorSupply = {
        -- bcc-banks: loans, checks, box fees and gold exchange settle against the
        -- branch reserve; only the one-time balance import and funding a reserve
        -- create currency.
        ['bcc-banks'] = {
            ['bank.migration.import'] = true,
            ['bank.reserve.funding'] = true
        },
    },
    -- The reason and reference every obligation settlement must carry. Operators
    -- cannot register this reason for themselves.
    Settlement = {
        reasonCode = 'contracts.settlement',
        referenceType = 'contract_obligation'
    },
    -- Issue and Destroy need an explicit Core policy grant (issueAction or
    -- destroyAction) for the calling resource. Keep enabled for production;
    -- trust lists alone never allow creating or destroying currency.
    Authorization = {
        enabled = true,
        issueAction = 'economy.currency.issue',
        destroyAction = 'economy.currency.destroy'
    },
    Outbox = {
        pollIntervalMs = 1000,
        retryDelaySeconds = 5,
        batchSize = 25
    },
    Currencies = {
        dollars = {
            label = 'Dollars',
            precision = 2,
            enabled = true
        },
        gold = {
            label = 'Gold',
            precision = 2,
            enabled = true
        }
    },
    Limits = {
        readinessTimeoutMs = 30000,
        maximumPageSize = 100,
        maximumReasonLength = 64,
        maximumReferenceLength = 128,
        maximumIdempotencyKeyLength = 128,
        maximumTransferAmount = 1000000000000,
        maximumBalance = 9000000000000000
    }
}
