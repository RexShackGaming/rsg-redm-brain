'use strict';
const net = require('node:net');

// Test-only plaintext MySQL wire proxy. Forward COMMIT exactly once, then consume
// its server reply without delivering it. No query injection or retry.
async function commitReplyProxy(upstream) {
    const sockets = new Set();
    const evidence = { commitsForwarded: 0, repliesDropped: 0 };
    const server = net.createServer(client => {
        const remote = net.createConnection(upstream);
        sockets.add(client); sockets.add(remote);
        let pending = Buffer.alloc(0), dropping = false;
        const close = () => { client.destroy(); remote.destroy(); };
        for (const socket of [client, remote]) {
            socket.on('error', close);
            socket.on('close', () => { sockets.delete(socket); close(); });
        }
        client.on('data', bytes => {
            pending = Buffer.concat([pending, bytes]);
            while (pending.length >= 4) {
                const length = pending.readUIntLE(0, 3) + 4;
                if (pending.length < length) break;
                const packet = pending.subarray(0, length);
                pending = pending.subarray(length);
                if (packet[4] === 3 && packet.subarray(5).toString().trim().toUpperCase() === 'COMMIT') {
                    dropping = true; evidence.commitsForwarded++;
                }
                remote.write(packet);
            }
        });
        remote.on('data', bytes => {
            if (dropping) { evidence.repliesDropped++; close(); }
            else client.write(bytes);
        });
    });
    await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
    return { port: server.address().port, evidence,
        close: async () => { for (const s of sockets) s.destroy(); await new Promise(resolve => server.close(resolve)); } };
}
module.exports = { commitReplyProxy };
