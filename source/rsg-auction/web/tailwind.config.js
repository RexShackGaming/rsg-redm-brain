/** @type {import('tailwindcss').Config} */
// RDR2 leather & gold theme: the stock palettes used by App.tsx are remapped to the
// monochrome theme tokens, so every existing utility class picks up the new look.
const stone = {
  50: '#ffffff', 100: '#ffffff', 200: '#f2f2f2', 300: '#d6d6d6', 400: '#9a9a9a',
  500: '#7c7c7c', 600: '#5a5a5a', 700: '#1c1c1c', 800: '#141414', 900: '#0a0a0a', 950: '#000000',
};
const accent = { // was amber/gold -> white/grey accent
  50: '#ffffff', 100: '#ffffff', 200: '#ffffff', 300: '#f2f2f2', 400: '#ffffff', 500: '#ffffff',
  600: '#4a4a4a', 700: '#2a2a2a', 800: '#1c1c1c', 900: '#141414', 950: '#0a0a0a',
};
const good = {
  50: '#e6f4e7', 100: '#d0ead1', 200: '#b9e4bb', 300: '#8fd493', 400: '#6fbf73', 500: '#6fbf73',
  600: '#5a7d4f', 700: '#4a6741', 800: '#2f4229', 900: '#1f2c1b', 950: '#141c11',
};
const bad = {
  50: '#fbe9e8', 100: '#f6d0ce', 200: '#f0aaa7', 300: '#ec7a75', 400: '#e0554f', 500: '#e0554f',
  600: '#9e3a35', 700: '#6e2724', 800: '#4a1a18', 900: '#2e1210', 950: '#1c0a09',
};
const warn = { ...accent, 300: '#eec06a', 400: '#d9a441', 500: '#d9a441' };

const palette = { stone, amber: accent, yellow: warn, orange: warn, emerald: good, green: good, red: bad, rose: bad, blue: accent, sky: accent };

module.exports = {
  content: ['./index.tsx', './App.tsx', './components/**/*.{ts,tsx}', './hooks/**/*.{ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: palette,
      // Borders read as the engraved gold-dim line rather than panel fills
      borderColor: {
        stone: { ...stone, 600: '#5a5a5a', 700: '#3a3a3a', 800: '#2a2a2a' },
        amber: { ...accent, 600: '#ffffff', 700: '#5a5a5a', 800: '#5a5a5a', 900: '#3a3a3a' },
      },
      fontFamily: { sans: ['Roboto', 'sans-serif'], mono: ['Roboto', 'monospace'] },
      borderRadius: { DEFAULT: '2px', md: '2px', lg: '3px', xl: '3px', '2xl': '3px' },
    },
  },
  plugins: [],
};
