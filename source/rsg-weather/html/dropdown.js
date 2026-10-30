// Custom dropdown: native <select> popups crash the RedM CEF client.
// Each <select> is hidden and kept as the value store; a styled list replaces its popup.
(() => {
  let openMenu = null;
  const close = () => { if (openMenu) { openMenu.menu.remove(); openMenu.wrap.classList.remove('open'); openMenu = null; } };
  const label = sel => { const o = sel.options[sel.selectedIndex]; return o ? o.textContent : ''; };

  function enhance(sel) {
    if (sel._csel) return;
    const wrap = document.createElement('div');
    wrap.className = 'csel';
    wrap.tabIndex = 0;
    wrap.innerHTML = '<span class="csel-text"></span><span class="csel-arrow">&#9662;</span>';
    sel.style.display = 'none';
    sel.after(wrap);
    sel._csel = wrap;
    const refresh = () => { wrap.querySelector('.csel-text').textContent = label(sel); };
    sel._cselRefresh = refresh;
    refresh();
    new MutationObserver(refresh).observe(sel, { childList: true, subtree: true, attributes: true, characterData: true });

    wrap.addEventListener('mousedown', e => {
      e.preventDefault(); e.stopPropagation();
      if (openMenu && openMenu.wrap === wrap) return close();
      close();
      const r = wrap.getBoundingClientRect();
      const menu = document.createElement('div');
      menu.className = 'csel-menu';
      [...sel.options].forEach((o, i) => {
        const it = document.createElement('div');
        it.className = 'csel-item' + (i === sel.selectedIndex ? ' active' : '');
        it.textContent = o.textContent;
        it.addEventListener('mousedown', ev => {
          ev.preventDefault(); ev.stopPropagation();
          close();
          if (sel.selectedIndex !== i) {
            sel.selectedIndex = i; refresh();
            sel.dispatchEvent(new Event('input', { bubbles: true }));
            sel.dispatchEvent(new Event('change', { bubbles: true }));
          }
        });
        menu.appendChild(it);
      });
      document.body.appendChild(menu);
      const below = window.innerHeight - r.bottom - 8, above = r.top - 8;
      const h = Math.min(menu.scrollHeight, 200);
      menu.style.left = r.left + 'px';
      menu.style.width = r.width + 'px';
      menu.style.maxHeight = '200px';
      menu.style.top = (below >= h || below >= above ? r.bottom + 2 : r.top - h - 2) + 'px';
      const act = menu.querySelector('.active'); if (act) act.scrollIntoView({ block: 'nearest' });
      wrap.classList.add('open');
      openMenu = { wrap, menu };
    });
  }

  // keep the label in sync when script.js sets .value / .selectedIndex directly
  ['value', 'selectedIndex'].forEach(p => {
    const d = Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, p);
    Object.defineProperty(HTMLSelectElement.prototype, p, {
      get() { return d.get.call(this); },
      set(v) { d.set.call(this, v); if (this._cselRefresh) this._cselRefresh(); },
      configurable: true,
    });
  });

  const scan = root => {
    if (root.tagName === 'SELECT') enhance(root);
    if (root.querySelectorAll) root.querySelectorAll('select').forEach(enhance);
  };
  window.closeDropdowns = close;
  document.addEventListener('mousedown', close);
  document.addEventListener('keydown', e => { if (e.key === 'Escape') close(); }, true);
  document.addEventListener('wheel', e => { if (openMenu && !openMenu.menu.contains(e.target)) close(); }, true);
  window.addEventListener('message', e => { if (e.data && (e.data.action === 'close' || e.data.type === 'close')) close(); });
  const start = () => {
    scan(document.body);
    new MutationObserver(ms => ms.forEach(m => m.addedNodes.forEach(n => n.nodeType === 1 && scan(n))))
      .observe(document.body, { childList: true, subtree: true });
  };
  document.readyState === 'loading' ? document.addEventListener('DOMContentLoaded', start) : start();
})();
