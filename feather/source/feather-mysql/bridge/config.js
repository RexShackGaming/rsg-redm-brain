'use strict';

// Configuration failures carry only static, credential-free messages, so the
// bridge may print them. Anything else that fails is reported generically.
class ConfigError extends Error {
    constructor(message) {
        super(message);
        this.name = 'ConfigError';
    }
}

function integer(value, fallback, min, max, name = 'numeric setting') {
    if (value === undefined || value === '') return fallback;
    const number = Number(value);
    if (!Number.isInteger(number) || number < min || number > max) {
        throw new ConfigError(`Invalid ${name}: expected an integer from ${min} to ${max}`);
    }
    return number;
}

function parseUrl(text) {
    let url;
    try { url = new URL(text); }
    catch (_) { throw new ConfigError('mysql_connection_string is not a valid mysql:// URL'); }
    if (url.hash) throw new ConfigError('Encode special characters in connection URLs');
    let decoded;
    try {
        decoded = {
            user: decodeURIComponent(url.username), password: decodeURIComponent(url.password),
            database: decodeURIComponent(url.pathname.slice(1)),
        };
    } catch (_) { throw new ConfigError('mysql_connection_string contains invalid percent-encoding'); }
    return { url, decoded };
}

function parseConnectionString(text) {
    if (typeof text !== 'string' || !text.trim()) throw new ConfigError('Missing mysql_connection_string');
    const values = Object.create(null);
    if (/^mysql:\/\//i.test(text)) {
        const { url, decoded } = parseUrl(text);
        Object.assign(values, {
            host: url.hostname.replace(/^\[|\]$/g, ''), port: url.port, ...decoded,
        });
        for (const [key, value] of url.searchParams) values[key.toLowerCase()] = value;
    } else {
        for (const part of text.split(';')) {
            if (!part.trim()) continue;
            const separator = part.indexOf('=');
            if (separator < 1) throw new ConfigError('Invalid connection string');
            const key = part.slice(0, separator).trim().toLowerCase();
            // Preserve credential whitespace and equals signs.
            values[key] = part.slice(separator + 1);
        }
    }
    const aliases = { server: 'host', uid: 'user', username: 'user', pwd: 'password', 'initial catalog': 'database' };
    for (const [alias, key] of Object.entries(aliases)) {
        if (values[alias] !== undefined) { values[key] = values[alias]; delete values[alias]; }
    }
    const allowed = new Set(['host', 'port', 'user', 'password', 'database', 'charset', 'ssl',
        'connectionlimit', 'queuelimit', 'connecttimeout']);
    for (const key of Object.keys(values)) if (!allowed.has(key)) throw new ConfigError('Unsupported connection option');
    if (!values.user || !values.database) throw new ConfigError('User and database are required');
    if (values.ssl !== undefined && !['true', 'false'].includes(values.ssl)) throw new ConfigError('ssl must be true or false');
    const charset = values.charset || 'utf8mb4';
    if (!/^[A-Za-z0-9_]{1,64}$/.test(charset)) throw new ConfigError('Invalid charset name');
    return {
        host: values.host || '127.0.0.1',
        port: integer(values.port, 3306, 1, 65535, 'port'),
        user: values.user, password: values.password || '', database: values.database,
        charset,
        connectionLimit: integer(values.connectionlimit, 10, 1, 1000, 'connectionLimit'),
        // Requests beyond connectionLimit wait here, in arrival order, and are
        // bounded twice: by this length and by the query deadline.
        queueLimit: integer(values.queuelimit, 512, 1, 100000, 'queueLimit'),
        connectTimeout: integer(values.connecttimeout, 10000, 1, 300000, 'connectTimeout'),
        ssl: values.ssl === 'true' ? { rejectUnauthorized: true } : undefined,
        // These cannot be overridden through the connection string.
        waitForConnections: true,
        multipleStatements: false,
        namedPlaceholders: false,
        // Integers are numbers while they fit in 2^53; larger BIGINT values are
        // strings so no precision is lost. DECIMAL always stays a string.
        supportBigNumbers: true,
        bigNumberStrings: false,
        decimalNumbers: false,
        // Rows are read positionally so duplicate column names cannot collapse
        // and DB.value always reads the first selected column.
        rowsAsArray: true,
        dateStrings: true,
        jsonStrings: true,
        timezone: 'Z',
        maxPreparedStatements: 128,
        flags: ['-LOCAL_FILES'],
    };
}

const POOL_ONLY = ['connectionLimit', 'queueLimit', 'waitForConnections', 'rowsAsArray'];

// Options for a one-off connection (used to cancel abandoned statements). Pool
// keys are removed because mysql2 warns about them on a plain connection.
function connectionOptions(config) {
    const options = { ...config };
    for (const key of POOL_ONLY) delete options[key];
    return options;
}

module.exports = { parseConnectionString, connectionOptions, integer, ConfigError };
