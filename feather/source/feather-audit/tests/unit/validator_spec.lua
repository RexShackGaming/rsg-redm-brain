local Assert = _G.TestAssert
local Fixtures = _G.TestFixtures
local now = 1788377071

local valid = FeatherAuditValidator.Validate(Fixtures.validTransfer(), {
    nowEpoch = now,
    sourceResource = 'feather-economy',
    sourceInstance = 'test-1'
})
Assert.truthy(valid.ok)
Assert.truthy(type(valid.canonical) == 'string')

local wrongSource = FeatherAuditValidator.Validate(Fixtures.validTransfer(), {
    nowEpoch = now,
    sourceResource = 'feather-admin'
})
Assert.falsy(wrongSource.ok)
Assert.equal(FeatherAuditResults.sourceMismatch, wrongSource.code)

local unknownContext = Fixtures.validTransfer()
unknownContext.context.unregistered = true
local unknown = FeatherAuditValidator.Validate(unknownContext, { nowEpoch = now })
Assert.falsy(unknown.ok)
Assert.equal(FeatherAuditResults.contextUnknownField, unknown.code)

local invalidContextKey = Fixtures.validTransfer()
invalidContextKey.context.unknownField = true
local invalidKey = FeatherAuditValidator.Validate(invalidContextKey, { nowEpoch = now })
Assert.equal(FeatherAuditResults.fieldInvalid, invalidKey.code)
Assert.equal('$.context.unknownField', invalidKey.path)

local unknownSnakeKey = Fixtures.validTransfer()
unknownSnakeKey.context.unknown_field = true
local unknownKey = FeatherAuditValidator.Validate(unknownSnakeKey, { nowEpoch = now })
Assert.equal(FeatherAuditResults.contextUnknownField, unknownKey.code)
Assert.equal('$.context.unknown_field', unknownKey.path)

local secret = Fixtures.validTransfer({ summary = 'https://discord.com/api/webhooks/123/secret' })
local prohibited = FeatherAuditValidator.Validate(secret, { nowEpoch = now })
Assert.falsy(prohibited.ok)
Assert.equal(FeatherAuditResults.prohibitedContent, prohibited.code)

local mixedTargets = Fixtures.validTransfer()
mixedTargets.targets.hidden = { type = 'account', id = 'hidden', role = 'credit' }
local mixed = FeatherAuditValidator.Validate(mixedTargets, { nowEpoch = now })
Assert.falsy(mixed.ok)
Assert.equal(FeatherAuditResults.fieldInvalid, mixed.code)

local future = Fixtures.validTransfer({ occurredAt = '2026-09-04T18:24:31Z' })
local futureResult = FeatherAuditValidator.Validate(future, { nowEpoch = now })
Assert.falsy(futureResult.ok)
Assert.equal(FeatherAuditResults.occurredAtFuture, futureResult.code)
