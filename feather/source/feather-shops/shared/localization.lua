-- feather-settings owns selection through Core. Dictionaries are resource-owned;
-- missing selected-language keys always fall back to these English strings.
local english={
 browse='Browse shop',boxes='Boxes',box_of='Box of %d',contents='%d rounds per box.',
 delivered='Rounds delivered: %d',item_count='%d item(s)',round_count='%d rounds',
 ammo_revolver='Revolver cartridges',ammo_pistol='Pistol cartridges',ammo_repeater='Repeater cartridges',
 ammo_rifle='Rifle cartridges',ammo_shotgun='Shotgun shells',ammo_varmint='Varmint cartridges',
 ammo_arrow='Arrows',ammo_other_ammo='Other ammunition',
 category_revolver='Revolvers',category_pistol='Pistols',category_repeater='Repeaters',
 category_rifle='Rifles',category_shotgun='Shotguns',category_ammunition='Ammunition',
 category_attachments='Attachments',category_maintenance='Maintenance',category_goods='Goods',
 error_generic='Purchase unavailable. Please review the shop again.',
 error_checkout_pending='Your purchase is being checked automatically. Please wait.',
 error_checkout_not_accepted='This purchase request is closed. You can review a new price.',
 error_checkout_not_committed='The purchase did not complete. No payment was taken.',
 error_insufficient_funds='You do not have enough money. No purchase was completed.',
 error_limit_exceeded='Your inventory cannot hold this purchase.',
 error_item_limit='You cannot carry more of this item.',
 error_item_restricted='You cannot carry this item here.',
 error_weight_limit='This purchase is too heavy to carry.',
 error_currency_unavailable='This currency is currently unavailable.',
 error_inventory_full='Your inventory is full.',
 error_invalid_quantity='Choose a permitted whole-number quantity. Buy firearms one at a time.',
 error_item_unavailable='This item is not currently available for purchase.',
 error_out_of_range='Move closer to the shop.',
 error_session_expired='Return to the character who started this purchase.',
 error_account_closed='This purchase wallet or business account is closed.',
 error_not_ready='The shop is not ready yet. Please wait.',
 error_quote_expired='The price has expired. Please review a new price.',
 error_catalog_changed='The offer changed. Please review a new price.',
 checking='Checking purchase',check_status='Check purchase status',
 saved='The saved request is checked automatically. No payment or delivery is repeated.',
 fulfilled='Purchase fulfilled. Items delivered.',
 earlier='An earlier purchase is being checked before a new purchase.',
 wallet='Wallet',wallet_unavailable='Wallet balance unavailable.',
 quantity='Quantity',review='Review price',confirm='Confirm purchase',pay='Confirm and pay',
 cancel='Cancel',back='Back',close='Close',shop='Shop',
 quote_unavailable='Quote unavailable.',core_unavailable='Core is not ready.',catalog_unavailable='Shop catalog unavailable.',
 total='Total: ',expires='Quote expires shortly.',language_changed='Language updated. Reopen the shop.'
}
local registered={}
for key,value in pairs(english) do registered['ui_shops_'..key]=value end
exports['feather-core']:RegisterLocale('en',registered)
function ShopText(source,key,...)
    local fallback=english[key] or english.error_generic
    local args=table.pack(...)
    local called,result=pcall(function() return exports['feather-core']:TranslateLocale(source,'ui_shops_'..key,table.unpack(args,1,args.n)) end)
    if called and type(result)=='table' and result.ok and type(result.value)=='string'
        and not result.value:match('^Translation %[') and not result.value:match('^Locale %[') then return result.value end
    return string.format(fallback,...)
end

-- Catalog labels can be translated by item/store key. The provider's English
-- label is the fallback; selection remains feather-settings' Core account locale.
function ShopCatalogText(source,key,fallback)
    local called,result=pcall(function() return exports['feather-core']:TranslateLocale(source,key) end)
    if called and type(result)=='table' and result.ok and type(result.value)=='string'
        and not result.value:match('^Translation %[') and not result.value:match('^Locale %[') then return result.value end
    return fallback
end
