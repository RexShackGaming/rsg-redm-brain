# feather-contracts

Version 0.2.0. Authoritative payable obligations for the Feather Framework

Authoritative payable obligations for the Feather Framework: invoices, bills, fines, rent, taxes, court awards and similar debts, with their lifecycle and settlement through Feather Economy.

Source: https://github.com/FeatherFramework/feather-contracts

**Dependencies:** `feather-mysql`, `feather-core`, `feather-economy`

## Exports (call as exports['feather-contracts']:Name)

**server:** `AcceptObligation(request, context)`, `AwaitReady(timeoutMs)`, `CancelObligation(request, context)`, `CreateDraft(request, context)`, `DisputeObligation(request, context)`, `GetCapabilities()`, `GetHealth()`, `GetObligation(request)`, `GetObligationType(request)`, `IssueObligation(request, context)`, `ListPartyObligations(request)`, `MarkDefaulted(request, context)`, `ReconcileSettlements()`, `RegisterObligationType(definition)`, `ResolveDispute(request, context)`, `SettleObligation(request, context)`

## Commands (RegisterCommand)

**server:** `/ContractsAuditSmokeTest`, `/ContractsFoundationSmokeTest`, `/ContractsLiveTest`, `/ContractsOrganizationTest`, `/ContractsReconcile`, `/ContractsReleaseSmokeTest`

## Public (table) functions

**server/logging.lua:** `ContractsLogging.Create(component)`, `logger.Info(event, fields)`, `logger.Warn(event, fields)`, `logger.Error(event, fields)`

**server/persistence/migrations.lua:** `ContractsMigrationRunner.Run()`

**server/repositories/obligations.lua:** `ContractsObligationRepository.Snapshot(row)`, `ContractsObligationRepository.ClientView(snapshot)`, `ContractsObligationRepository.Get(obligationId)`, `ContractsObligationRepository.Lock(tx, obligationId)`, `ContractsObligationRepository.RecordAction(tx, obligationId, actionType, fromStatus, toStatus,
    revision, context, economyTransactionId)`, `ContractsObligationRepository.ListParty(options)`

**server/services/api.lua:** `ContractsAPI.GetCapabilities()`, `ContractsAPI.GetHealth()`, `ContractsAPI.AwaitReady(timeoutMs)`, `ContractsAPI.RegisterObligationType(definition, resource)`, `ContractsAPI.GetObligationType(request)`, `ContractsAPI.AcceptObligation(request, context, resource)`, `ContractsAPI.DisputeObligation(request, context, resource)`, `ContractsAPI.SettleObligation(request, context, resource)`

**server/services/economy.lua:** `ContractsEconomy.RequireCurrency(code)`, `ContractsEconomy.ResolveCreditorAccount(creditorType, creditorId, currency)`, `ContractsEconomy.ResolveDebtorAccount(debtor, currency)`, `ContractsEconomy.TreasuryOperator(organizationId, currency)`, `ContractsEconomy.OrganizationOperator(organizationId)`, `ContractsEconomy.Settle(settlement)`, `ContractsEconomy.CanReadTransactions()`, `ContractsEconomy.GetTransaction(transactionId)`

**server/services/foundation.lua:** `ContractsFoundation.BeginStartup()`, `ContractsFoundation.MarkCheck(name, details)`, `ContractsFoundation.MarkStarting(phase)`, `ContractsFoundation.MarkReady()`, `ContractsFoundation.MarkFailed(code, message, details)`, `ContractsFoundation.MarkStopping()`, `ContractsFoundation.IsReady()`, `ContractsFoundation.RequireReady()`, `ContractsFoundation.GetHealth()`, `ContractsFoundation.GetCapabilities()`, `ContractsFoundation.AwaitReady(timeoutMs)`

**server/services/obligations.lua:** `ContractsObligations.ServerContext(resource, context)`, `ContractsObligations.Authorize(action, resource, correlationId, subject)`, `ContractsObligations.EventPayload(snapshot, previousStatus, context, extra)`, `ContractsObligations.Mutate(spec)`, `ContractsObligations.CreateDraft(request, context, resource)`, `ContractsObligations.IssueObligation(request, context, resource)`, `ContractsObligations.AcceptObligation(request, context, resource, viaClient)`, `ContractsObligations.DisputeObligation(request, context, resource, viaClient)`, `ContractsObligations.ResolveDispute(request, context, resource)`, `ContractsObligations.CancelObligation(request, context, resource)`, `ContractsObligations.MarkDefaulted(request, context, resource)`, `ContractsObligations.GetObligation(request, resource)`, `ContractsObligations.ValidateListOptions(request, allowParty)`, `ContractsObligations.ListPartyObligations(request, resource)`

**server/services/outbox.lua:** `ContractsOutbox.Record(tx, eventKey, aggregateId, payload)`, `ContractsOutbox.Start()`, `ContractsOutbox.Stop()`, `ContractsOutbox.GetState()`

**server/services/receipts.lua:** `ContractsReceipts.Reserve(tx, resource, operation, requestId, fingerprint)`, `ContractsReceipts.Complete(tx, resource, operation, requestId, value)`

**server/services/routes.lua:** `ContractsRoutes.Register()`, `ContractsRoutes.Names()`

**server/services/scheduler.lua:** `ContractsScheduler.RunOnce()`, `ContractsScheduler.Start()`, `ContractsScheduler.Stop()`, `ContractsScheduler.IsRunning()`

**server/services/settlement.lua:** `ContractsSettlement.Drive(settlementId)`, `ContractsSettlement.SettleObligation(request, context, resource, viaClient)`, `ContractsSettlement.ProcessPending(limit, force)`, `ContractsSettlement.Audit()`, `ContractsSettlement.VerifyWithEconomy(limit)`, `ContractsSettlement.Reconcile(resource)`

**server/services/types.lua:** `ContractsTypes.Normalize(definition)`, `ContractsTypes.Transitions(requiresAcceptance, debtorMayDispute)`, `ContractsTypes.Allows(transitions, operation, status)`, `ContractsTypes.Load()`, `ContractsTypes.Register(definition, resource)`, `ContractsTypes.Get(request)`, `ContractsTypes.RequireOwnedActive(typeKey, resource)`, `ContractsTypes.Owner(typeKey)`, `ContractsTypes.Count()`

**server/services/validation.lua:** `ContractsValidation.Uuid(value)`, `ContractsValidation.Integer(value, minimum, maximum)`, `ContractsValidation.Key(value, maximum)`, `ContractsValidation.Code(value, maximum)`, `ContractsValidation.Text(value, maximum)`, `ContractsValidation.RequestId(value, maximum)`, `ContractsValidation.Fields(request, allowed, label)`, `ContractsValidation.Fingerprint(values)`, `ContractsValidation.Lower(value)`, `ContractsValidation.Transaction(label, body)`, `ContractsValidation.NewUuid(tx)`

**server/tests.lua:** `runner.Check(name, condition)`, `runner.Done(note)`

**shared/results.lua:** `ContractsResults.Ok(value, meta)`, `ContractsResults.Err(code, message, details)`, `ContractsResults.Is(value)`
