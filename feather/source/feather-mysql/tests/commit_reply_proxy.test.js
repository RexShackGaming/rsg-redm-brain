'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const net = require('node:net');
const { once } = require('node:events');
const { commitReplyProxy } = require('./commit_reply_proxy');
const { publicError } = require('../bridge/errors');
test('raw mysql2 connection loss is unknown at the actual public bridge boundary', () => {
    const raw = Object.assign(new Error('not exposed'), {code:'PROTOCOL_CONNECTION_LOST',fatal:true});
    assert.equal(raw.outcome,undefined);
    assert.equal(publicError(raw).outcome,'unknown');
    assert.equal(publicError(raw).driverCode,'PROTOCOL_CONNECTION_LOST');
});
function packet(text) {
    const body = Buffer.concat([Buffer.from([3]), Buffer.from(text)]);
    const header = Buffer.alloc(4); header.writeUIntLE(body.length,0,3);
    return Buffer.concat([header,body]);
}
test('wire proxy forwards fragmented commands once and suppresses only COMMIT response', async () => {
    const received = [];
    const upstream = net.createServer(socket => socket.on('data', bytes => {
        received.push(bytes); socket.write(Buffer.from([1,0,0,1,0]));
    }));
    upstream.listen(0,'127.0.0.1'); await once(upstream,'listening');
    const proxy = await commitReplyProxy({host:'127.0.0.1',port:upstream.address().port});
    const client = net.createConnection({host:'127.0.0.1',port:proxy.port});
    try {
        await once(client,'connect');
        const reply = once(client,'data'); client.write(packet('SELECT 1'));
        assert.deepEqual((await reply)[0],Buffer.from([1,0,0,1,0]));
        const commit=packet('COMMIT'); const closed=once(client,'close');
        client.write(commit.subarray(0,2)); client.write(commit.subarray(2));
        let unexpected=false;client.on('data',()=>{unexpected=true;});
        await closed;
        assert.equal(unexpected,false);
        assert.deepEqual(Buffer.concat(received),Buffer.concat([packet('SELECT 1'),commit]));
        assert.deepEqual(proxy.evidence,{commitsForwarded:1,repliesDropped:1});
    } finally { client.destroy();await proxy.close();await new Promise(resolve=>upstream.close(resolve)); }
});
