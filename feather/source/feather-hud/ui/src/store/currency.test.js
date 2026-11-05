import test from 'node:test';
import assert from 'node:assert/strict';
import { splitCurrency } from './currency.js';

test('renders dollars and gold with two catalog decimals', () => {
    assert.deepEqual(splitCurrency(0, 2), { whole: '0', frac: '00' });
    assert.deepEqual(splitCurrency(201, 2), { whole: '2', frac: '01' });
    assert.deepEqual(splitCurrency(9, 2), { whole: '0', frac: '09' });
});
test('preserves large integer balances without division rounding', () => {
    assert.deepEqual(splitCurrency(8999999999999999, 2), { whole: '89999999999999', frac: '99' });
});
test('supports catalog precision including whole units', () => {
    assert.deepEqual(splitCurrency(42, 0), { whole: '42', frac: '' });
    assert.deepEqual(splitCurrency(42, 3), { whole: '0', frac: '042' });
});
test('invalid or unavailable values are not fabricated zero balances', () => {
    for (const value of [undefined, null, NaN, Infinity, -1, 1.5, '200', Number.MAX_SAFE_INTEGER + 1]) {
        assert.deepEqual(splitCurrency(value, 2), { whole: '—', frac: '' });
    }
    for (const precision of [-1, 7, 1.5, undefined]) {
        assert.deepEqual(splitCurrency(200, precision), { whole: '—', frac: '' });
    }
});
