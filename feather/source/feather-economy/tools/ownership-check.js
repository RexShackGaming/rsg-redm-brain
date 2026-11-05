#!/usr/bin/env node
// Economy ownership check (master plan E6): only feather-economy may write its
// tables, and no resource may keep or change balances on its own.
//
//   node tools/ownership-check.js <resources folder> [--cfg server.cfg] [--allow name]... [--strict]
//
// Scans .lua, .js, .ts and .sql files of every resource under the folder (with
// --cfg, only resources that server.cfg ensures or starts, including bracket
// categories). Exit code 1 when an error is found.
//
// Errors:
//   economy-table-write   SQL that creates, alters, inserts, updates, deletes or drops an economy_* table
//   balance-column-write  UPDATE ... SET of a money column (money, gold, rol, cash, balance, ledger)
//   legacy-currency-api   VORP or Cfx example currency calls (addCurrency, removeMoney, exports.money ...)
// Warnings (errors with --strict):
//   economy-table-read    SQL that reads an economy_* table instead of using Economy exports
//
// --allow <resource> skips a resource (for example one being retired). It is not
// for real balance writers: port them to Economy.

'use strict';
const fs = require('fs');
const path = require('path');

const OWNER = 'feather-economy';
const EXTENSIONS = new Set(['.lua', '.js', '.ts', '.sql']);
const SKIP_DIRS = new Set(['node_modules', '.git', 'dist', 'stream']);

const RULES = [
    {
        id: 'economy-table-write', level: 'error',
        pattern: /\b(INSERT\s+(?:IGNORE\s+)?INTO|REPLACE\s+INTO|UPDATE|DELETE\s+FROM|ALTER\s+TABLE|DROP\s+TABLE(?:\s+IF\s+EXISTS)?|TRUNCATE(?:\s+TABLE)?|CREATE\s+TABLE(?:\s+IF\s+NOT\s+EXISTS)?)\s+`?(economy_\w+)/gi
    },
    {
        id: 'economy-table-read', level: 'warning',
        pattern: /(?<!\bDELETE\s+)\b(FROM|JOIN)\s+`?(economy_\w+)/gi
    },
    {
        id: 'balance-column-write', level: 'error',
        pattern: /\bUPDATE\s+`?\w+`?\s+SET\b([\s\S]{0,300}?)(?:\bWHERE\b|;|\]\]|$)/gi,
        accept: (match) => /(^|[\s,`.])`?(money|gold|rol|cash|balance|ledger)`?\s*=/i.test(match[1])
    },
    {
        id: 'legacy-currency-api', level: 'error',
        pattern: /\b(addCurrency|removeCurrency|setCurrency|addMoney|removeMoney|setMoney)\s*\(|exports\s*(?:\[\s*['"]money['"]\s*\]|\.money\b)/g
    }
];

function usage(message) {
    if (message) console.error(message);
    console.error('usage: node tools/ownership-check.js <resources folder> [--cfg server.cfg] [--allow name]... [--strict]');
    process.exit(2);
}

function parseArgs(argv) {
    const options = { root: null, cfg: null, allow: new Set(), strict: false };
    for (let i = 0; i < argv.length; i++) {
        const arg = argv[i];
        if (arg === '--cfg') options.cfg = argv[++i] || usage('--cfg needs a file');
        else if (arg === '--allow') options.allow.add(argv[++i] || usage('--allow needs a resource name'));
        else if (arg === '--strict') options.strict = true;
        else if (arg.startsWith('--')) usage('unknown option ' + arg);
        else if (!options.root) options.root = arg;
        else usage('only one resources folder');
    }
    if (!options.root) usage();
    return options;
}

// Resources are folders holding an fxmanifest.lua (or legacy __resource.lua);
// folders named [category] only group them.
function findResources(dir, category, found) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (!entry.isDirectory() || SKIP_DIRS.has(entry.name)) continue;
        const full = path.join(dir, entry.name);
        if (entry.name.startsWith('[') && entry.name.endsWith(']')) {
            findResources(full, [...category, entry.name], found);
        } else if (fs.existsSync(path.join(full, 'fxmanifest.lua')) || fs.existsSync(path.join(full, '__resource.lua'))) {
            found.push({ name: entry.name, dir: full, category });
        }
    }
    return found;
}

// Names and [categories] that server.cfg ensures or starts (comments ignored).
function startedFromCfg(file) {
    if (!fs.existsSync(file)) usage('server.cfg not found: ' + file);
    const started = new Set();
    for (const raw of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
        const line = raw.replace(/(#|\/\/).*$/, '').trim();
        const match = line.match(/^(ensure|start)\s+(\S+)/i);
        if (match) started.add(match[2]);
    }
    return started;
}

function sourceFiles(dir, files = []) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (SKIP_DIRS.has(entry.name)) continue;
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) sourceFiles(full, files);
        else if (EXTENSIONS.has(path.extname(entry.name).toLowerCase())) files.push(full);
    }
    return files;
}

function lineOf(text, index) {
    let line = 1;
    for (let i = 0; i < index; i++) if (text.charCodeAt(i) === 10) line++;
    return line;
}

function scan(resource, root) {
    const findings = [];
    const seen = new Set();
    for (const file of sourceFiles(resource.dir)) {
        const text = fs.readFileSync(file, 'utf8');
        for (const rule of RULES) {
            rule.pattern.lastIndex = 0;
            let match;
            while ((match = rule.pattern.exec(text)) !== null) {
                if (match[0] === '') { rule.pattern.lastIndex++; continue; }
                if (rule.accept && !rule.accept(match)) continue;
                const line = lineOf(text, match.index);
                const key = `${rule.id}:${file}:${line}`;
                if (seen.has(key)) continue;
                seen.add(key);
                const snippet = text.split(/\r?\n/)[line - 1].trim().slice(0, 140);
                findings.push({ rule: rule.id, level: rule.level, resource: resource.name,
                    file: path.relative(root, file), line, snippet });
            }
        }
    }
    return findings;
}

function main() {
    const options = parseArgs(process.argv.slice(2));
    const root = path.resolve(options.root);
    if (!fs.existsSync(root)) usage('resources folder not found: ' + root);
    let resources = findResources(root, [], []);
    if (options.cfg) {
        const started = startedFromCfg(options.cfg);
        resources = resources.filter((r) => started.has(r.name) || r.category.some((c) => started.has(c)));
    }
    resources = resources.filter((r) => r.name !== OWNER && !options.allow.has(r.name));

    const findings = resources.flatMap((r) => scan(r, root));
    let errors = 0, warnings = 0;
    for (const finding of findings) {
        const level = finding.level === 'warning' && options.strict ? 'error' : finding.level;
        if (level === 'error') errors++; else warnings++;
        console.log(`${level.toUpperCase()} ${finding.rule} ${finding.file}:${finding.line}\n    ${finding.snippet}`);
    }
    console.log(`[EconomyOwnershipCheck] ${resources.length} resources scanned` +
        `${options.cfg ? ' (started in ' + path.basename(options.cfg) + ')' : ''}: ` +
        `${errors} error(s), ${warnings} warning(s) -> ${errors === 0 ? 'PASS' : 'FAIL'}`);
    process.exit(errors === 0 ? 0 : 1);
}

main();
