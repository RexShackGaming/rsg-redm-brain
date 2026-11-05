Config = {
    Contract = 1,
    DevMode = false,
    ReadinessTimeoutMs = 30000,
    MaximumOffersPerShop = 100,
    Reconciliation = { enabled = true, pollIntervalMs = 5000, retryDelaySeconds = 15, batchSize = 10 },
    Quotes = {
        lifetimeSeconds = 30,
        maximumDistance = 4.0,
        trustedCallers = { ['feather-shops'] = true }
    },
    Shops = {
        {
            id = '00000000-0000-4000-8000-000000000001',
            label = 'Valentine General Store',
            organization = { key='valentine_general_store', legalName='Valentine General Store Company', displayName='Valentine General Store' },
            position = { x = -322.13, y = 803.65, z = 117.88 },
            heading = 0.0,
            offers = {
                {
                    id = '00000000-0000-4000-8000-000000000101',
                    itemName = 'consumable_apple',
                    label = 'Apple',
                    currency = 'dollars',
                    unitPrice = 100,
                    maximumQuantity = 10
                }
            }
        }
    }
}

-- Development acceptance only; no Admin quote/order trust in production mode.
if Config.DevMode then Config.Quotes.trustedCallers['feather-admin']=true end
