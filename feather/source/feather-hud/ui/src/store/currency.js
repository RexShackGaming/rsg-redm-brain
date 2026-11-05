// Integer minor units avoid rounding a large balance through floating-point
// division. No balance derivation or ledger state belongs in this formatter.
export function splitCurrency(amount, precision) {
    if (!Number.isSafeInteger(amount) || amount < 0
        || !Number.isInteger(precision) || precision < 0 || precision > 6) {
        return { whole: '—', frac: '' };
    }
    const integer = BigInt(amount);
    const scale = 10n ** BigInt(precision);
    return {
        whole: (integer / scale).toString(),
        frac: precision === 0 ? '' : (integer % scale).toString().padStart(precision, '0')
    };
}
