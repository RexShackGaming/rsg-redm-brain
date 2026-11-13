-- Lookup tables built from Config.Sets (shared by client and server)
Cards = {
    Info   = {}, -- [itemName] = { set, tier, price, deck?, number?, model?, landscape?, order }
    List   = {}, -- every single card item name, in set order
    Decks  = {}, -- every complete-set item name
    ByTier = {}, -- [tier] = { itemName, ... }
    Total  = 0,  -- number of single cards
}

for setIndex, set in ipairs(Config.Sets) do
    local deck = ('card_cigcard_%s'):format(set.id)
    Cards.Decks[#Cards.Decks + 1] = deck
    Cards.Info[deck] = {
        set = set.id,
        tier = 'deck',
        deck = true,
        price = set.deckPrice,
        order = setIndex, -- sets list before single cards
    }

    Cards.ByTier[set.tier] = Cards.ByTier[set.tier] or {}
    for number = 1, Config.CardsPerSet do
        local name = ('card_cigcard_%s_c%d'):format(set.id, number)
        Cards.Info[name] = {
            set = set.id,
            tier = set.tier,
            number = number,
            price = set.cardPrice,
            model = ('s_inv_cigcard_%s_%02dx'):format(set.id, number),
            landscape = set.landscape == true,
            order = setIndex * 100 + number,
        }
        Cards.List[#Cards.List + 1] = name
        Cards.ByTier[set.tier][#Cards.ByTier[set.tier] + 1] = name
    end
end

Cards.Total = #Cards.List
