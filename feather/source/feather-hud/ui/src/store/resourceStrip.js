import { defineStore } from 'pinia';

// Flat state shape pushed straight from client/services/hud.lua -- level
// and xpPercent are derived from xp there (there's no `level` field
// anywhere in the character schema), so this store just holds whatever it's
// given rather than computing anything itself.
export const useResourceStripStore = defineStore('resourceStrip', {
    state: () => ({
        cash: 0,
        gold: 0,
        cashMinor: 0,
        goldMinor: 0,
        cashPrecision: 2,
        goldPrecision: 2,
        tokens: 0,
        xp: 0,
        level: 1,
        xpPercent: 0,
        visible: false,
        anchor: 'bottom-right',
        padding: 26,
        topPadding: 56,
        scale: 1.0,
        scrim: true
    }),
    actions: {
        applyState(state) {
            Object.assign(this, state);
        },
        applyConfig(config) {
            Object.assign(this, config);
        }
    }
})
