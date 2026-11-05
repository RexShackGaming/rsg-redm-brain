# Feather Authority

Feather Authority owns durable capability definitions, roles, grants,
assignments, scopes, expiry, suspension, revocation, and explainable decisions.
Core remains the authenticated policy-evaluation boundary, while every domain
continues to authorize its own protected mutations.

Contract 1 provides lifecycle/readiness, checksum-protected migrations, a bounded
capability registry, durable roles and grants, account and character assignments and lifecycle,
effective-capability evaluation, transactional service-owned staff assignment
replacement, and a named non-default Core policy provider.

## Startup order

Start Authority after Core and Organizations, and before Admin and protected
gameplay consumers:

```text
ensure feather-core
ensure feather-organizations
ensure feather-authority
ensure feather-admin
```

## Production posture

`Config.DevMode` defaults to `false`. Production keeps the Authority exports and
the read-only `AuthorityReleaseContractSmokeTest` console command available, but
does not register development contract, mutation, concurrency, or fixture commands.

Run after startup:

```text
AuthorityReleaseContractSmokeTest
```

Expected result: `8/8 passed`. Admin is the only production service trusted to
register capabilities, create and grant roles, and replace staff assignments.
Authority remains a named, non-default Core policy provider; Admin retains the
default composite provider for player and service-principal authorization.

For isolated acceptance testing only, set `Config.DevMode = true`, run `refresh`
after manifest changes when applicable, restart Authority, and use the development
commands. Return the flag to `false` before deployment.
