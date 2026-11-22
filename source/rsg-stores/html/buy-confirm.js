// Buy-store confirmation: Buy / Cancel. The client script shows it; the server still validates the purchase.
(function () {
    'use strict';
    var box = document.getElementById('buy-confirm');
    var open = false;

    function post(name, body) {
        fetch('https://' + ShopUI.resourceName + '/' + name, {
            method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {})
        }).catch(function () {});
    }
    function hide() { open = false; box.classList.add('hidden'); }
    function cancel() { if (!open) return; hide(); post('buyConfirmCancel'); }
    function buy(method) { if (!open) return; hide(); post('buyConfirmYes', { method: method }); }

    document.getElementById('bc-cancel').addEventListener('click', cancel);
    document.getElementById('bc-ok').addEventListener('click', function () { buy('cash'); });
    document.getElementById('bc-bank').addEventListener('click', function () { buy('bank'); });
    box.querySelector('.bc-backdrop').addEventListener('click', cancel);
    document.addEventListener('keydown', function (e) { if (open && e.key === 'Escape') { e.stopPropagation(); cancel(); } }, true);

    window.addEventListener('message', function (event) {
        var d = event.data;
        if (!d || !d.action) return;
        if (d.action === 'openBuyConfirm') {
            document.getElementById('bc-title').textContent = d.title || '';
            document.getElementById('bc-text').textContent = d.text || '';
            document.getElementById('bc-ok').textContent = d.ok || 'Pay with cash';
            var bank = document.getElementById('bc-bank');
            bank.textContent = d.bank || '';
            bank.classList.toggle('hidden', !d.bank);
            document.getElementById('bc-cancel').textContent = d.cancel || 'Cancel';
            open = true;
            box.classList.remove('hidden');
            document.getElementById('bc-cancel').focus(); // Enter cancels by default; buying needs a deliberate click
        } else if (d.action === 'closeBuyConfirm') {
            hide();
        }
    });
})();
