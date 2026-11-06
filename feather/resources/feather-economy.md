# feather-economy

Version 0.6.0. Authoritative monetary accounting service for the Feather Framework

Authoritative monetary accounting for the Feather Framework. Economy owns currencies, accounts, balances, an immutable balanced journal, idempotent monetary operations and a transactional outbox. Gameplay resources own prices,

Source: https://github.com/FeatherFramework/feather-economy

**Dependencies:** `feather-mysql`, `feather-core`

## Exports (call as exports['feather-economy']:Name)

**server:** `AwaitReady(timeoutMs)`, `CheckIssue(request,context)`, `Destroy(request, context)`, `EnsureCharacterBankAccounts(request)`, `EnsureCharacterWallets(request)`, `EnsureOperatedTreasury(request)`, `EnsureOrganizationTreasuries(request)`, `FindAccountsByOwner(request)`, `GetAccount(request)`, `GetCapabilities()`, `GetCurrency(code)`, `GetHealth()`, `GetSystemAccount(request)`, `GetTransaction(request)`, `Issue(request, context)`, `ListAccountEntries(request)`, `ListCurrencies()`, `RegisterOperatedReasons(request)`, `ReversePayment(request, context)`, `StageShopCheckoutPayment(query, orderId)`, `Transfer(request, context)`, `initiate()`

## Commands (RegisterCommand)

**server:** `/EconomyAccountContractSmokeTest`, `/EconomyBankAccountGateSmokeTest`, `/EconomyBankContractSmokeTest`, `/EconomyBankLiveTest`, `/EconomyConcurrencyTest`, `/EconomyFoundationSmokeTest`, `/EconomyHealthReport`, `/EconomyHistoryPaginationTest`, `/EconomyIssueReasonGateSmokeTest`, `/EconomyJournalAuditSmokeTest`, `/EconomyMigrationFaultTest`, `/EconomyPaymentReversalContractSmokeTest`, `/EconomyReleaseContractSmokeTest`, `/EconomyReleaseGateSmokeTest`, `/EconomyRestartTest`, `/EconomySettlementGateSmokeTest`, `/EconomyShopFundingTest`, `/EconomyStablesReversalContractSmokeTest`, `/EconomySupplyTest`, `/EconomyTransactionReadSmokeTest`, `/EconomyTransferContractSmokeTest`, `/EconomyTransferLiveTest`, `/EconomyTreasuryContractSmokeTest`, `/EconomyTreasuryProvisionTest`, `/EconomyTreasurySettlementContractSmokeTest`, `/EconomyWalletProvisionTest`

## Public (table) functions

**server/logging.lua:** `EconomyLogging.Create(component)`, `logger.Info(event, fields)`, `logger.Warn(event, fields)`, `logger.Error(event, fields)`

**server/persistence/migrations.lua:** `EconomyMigrationRunner.Run(definitions)`, `EconomyMigrationRunner.FaultDefinitions(kind)`

**server/repositories/accounts.lua:** `EconomyAccounts.Start()`, `EconomyAccounts.EnsureCharacterWallets(characterId)`, `EconomyAccounts.EnsureOrganizationTreasuries(organizationId)`, `EconomyAccounts.EnsureCharacterBankAccounts(characterId, accountRef)`, `EconomyAccounts.ListEntries(accountId, limit, offset, before)`, `EconomyAccounts.Get(accountId)`, `EconomyAccounts.FindByOwner(ownerType, ownerId)`

**server/repositories/currencies.lua:** `EconomyCurrencies.Start()`, `EconomyCurrencies.Get(code)`, `EconomyCurrencies.List()`, `EconomyCurrencies.Count()`

**server/services/api.lua:** `EconomyAPI.GetCapabilities()`, `EconomyAPI.GetHealth()`, `EconomyAPI.AwaitReady(timeoutMs)`, `EconomyAPI.GetCurrency(code)`, `EconomyAPI.ListCurrencies()`, `EconomyAPI.GetAccount(request, resource)`, `EconomyAPI.FindAccountsByOwner(request, resource)`, `EconomyAPI.EnsureCharacterWallets(request, resource)`, `EconomyAPI.EnsureCharacterBankAccounts(request, resource)`, `EconomyAPI.ListAccountEntries(request, resource)`, `EconomyAPI.GetTransaction(request, resource)`, `EconomyAPI.GetSystemAccount(request, resource)`, `EconomyAPI.EnsureOrganizationTreasuries(request, resource)`, `EconomyAPI.EnsureOperatedTreasury(request, resource)`, `EconomyAPI.RegisterOperatedReasons(request, resource)`, `EconomyAPI.Transfer(request, context, resource)`, `EconomyAPI.ReversePayment(request, context, resource)`, `EconomyAPI.Supply(operation,request,context,resource,authorize)`, `EconomyAPI.CheckIssue(request,context,resource,authorize)`, `EconomyAPI.Issue(request, context, resource)`, `EconomyAPI.Destroy(request, context, resource)`, `EconomyAPI.StageShopCheckoutPayment(query, orderId, resource)`

**server/services/foundation.lua:** `EconomyFoundation.BeginStartup()`, `EconomyFoundation.MarkMigrationsComplete(details)`, `EconomyFoundation.MarkCatalogReady(details)`, `EconomyFoundation.MarkAccountsReady(details)`, `EconomyFoundation.MarkReady()`, `EconomyFoundation.MarkFailed(code, message, details)`, `EconomyFoundation.GetHealth()`, `EconomyFoundation.GetCapabilities()`, `EconomyFoundation.AwaitReady(timeoutMs)`

**server/services/journal.lua:** `EconomyJournal.AccountTypesAllowed(operation, from, to, request, resource, context, database)`, `EconomyJournal.MayPost(operation, resource, reasonCode)`, `EconomyJournal.ApplyShopPayment(transaction, order, accounts)`, `EconomyJournal.Transfer(request, context)`, `EconomyJournal.ReversePayment(request, context)`, `EconomyJournal.GetTransaction(transactionId)`, `EconomyJournal.Issue(request, context)`, `EconomyJournal.Destroy(request, context)`

**server/services/operators.lua:** `EconomyOperators.SupplyAllowed(resource, reasonCode)`, `EconomyOperators.Allowed(operation, from, to, request, resource, context, database)`, `EconomyOperators.Register(resource, request)`, `EconomyOperators.Unregister(resource)`, `EconomyOperators.Registered(resource)`

**server/services/outbox.lua:** `EconomyOutbox.Start()`, `EconomyOutbox.Stop()`, `EconomyOutbox.GetState()`

**server/test_support.lua:** `EconomyTests.IsUuid(value)`, `EconomyTests.RequestId(value)`, `EconomyTests.Character(argument)`, `EconomyTests.Wallet(characterId, currency)`, `EconomyTests.Counter(name)`

**shared/results.lua:** `EconomyResults.Ok(value, meta)`, `EconomyResults.Err(code, message, details)`, `EconomyResults.Is(value)`
