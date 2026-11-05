# Automated development checks

Pull requests, pushes to main and release packaging run the Node regression
suite, Lua 5.4 contracts/syntax and isolated MariaDB integration tests on Ubuntu
with Node 22. The integration runner creates its own temporary database directory
and local socket; it never reads server.cfg or connects to an installed server's
database. Release packaging waits for these checks. The existing published-release
trigger is unchanged. Remote Windows fault-injection tools remain manual,
dedicated-test-only tools, not CI or installer steps.

For a development Ubuntu machine, install Node 22, Python 3.12, liblua5.4-0 and
mariadb-server, then run from this repository:

```sh
npm ci --ignore-scripts
npm test
npm run test:lua
npm run test:integration
```

These are development checks, not commands for the RedM server console.
