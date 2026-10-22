-- Money helpers. All values are stored internally as integer cents to avoid float precision issues.

Money = {}

-- 1.00 -> 100, "5.50" -> 550
function Money.dollarsToCents(dollars)
    dollars = tonumber(dollars)
    if not dollars then return 0 end
    return math.floor(dollars * 100 + 0.5)
end

-- 550 -> 5.5
function Money.centsToDollars(cents)
    if type(cents) ~= 'number' then return 0.0 end
    return cents / 100
end

-- 550 -> "$5.50"
function Money.format(cents)
    if type(cents) ~= 'number' then return '$0.00' end
    return string.format('$%d.%02d', math.floor(cents / 100), math.abs(cents % 100))
end

-- 123456 -> "$1,234.56"
function Money.formatWithCommas(cents)
    if type(cents) ~= 'number' then return '$0.00' end
    local dollars = tostring(math.floor(cents / 100)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return string.format('$%s.%02d', dollars, math.abs(cents % 100))
end
