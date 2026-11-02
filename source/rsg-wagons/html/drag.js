// Draggable UI panels. Drag a panel by its title bar; double-click the title bar to reset.
// Positions are remembered per panel in the NUI's localStorage.
(() => {
  const KEY = 'rsg-wagons:pos:';
  // [element selector, handle selector inside it, storage id]
  const targets = [
    // the wagon list and details panel swap in the same spot, so they share one position
    ['#catalogue', '.panel-header', 'main'],
    ['#details', '.details-head', 'main'],
    ['#custom', '.panel-header', 'custom'],
    ['#inputModal .modal-card', 'h2', 'inputModal'],
    ['#confirmModal .modal-card', 'h2', 'confirmModal'],
  ];

  const load = (id) => {
    try { const v = JSON.parse(localStorage.getItem(KEY + id)); if (v && isFinite(v.x) && isFinite(v.y)) return v; } catch (e) {}
    return { x: 0, y: 0 };
  };
  const save = (id, p) => { try { localStorage.setItem(KEY + id, JSON.stringify(p)); } catch (e) {} };
  const apply = (el, p) => { el.style.setProperty('--dx', p.x + 'px'); el.style.setProperty('--dy', p.y + 'px'); };

  const shared = {}; // id -> { pos, els: [] }
  const applyAll = (id) => shared[id].els.forEach((e) => apply(e, shared[id].pos));

  targets.forEach(([sel, handleSel, id]) => {
    const el = document.querySelector(sel);
    const handle = el && el.querySelector(handleSel);
    if (!el || !handle) return;
    el.classList.add('draggable');
    handle.classList.add('drag-handle');
    if (!shared[id]) shared[id] = { pos: load(id), els: [] };
    shared[id].els.push(el);
    apply(el, shared[id].pos);

    handle.addEventListener('mousedown', (e) => {
      if (e.button !== 0 || e.target.closest('button, input')) return;
      e.preventDefault();
      const startX = e.clientX, startY = e.clientY, start = { ...shared[id].pos };
      const r = el.getBoundingClientRect();
      // keep at least 40px of the panel on screen
      const minX = start.x - r.left - r.width + 40, maxX = start.x + (window.innerWidth - r.left) - 40;
      const minY = start.y - r.top, maxY = start.y + (window.innerHeight - r.top) - 40;
      el.classList.add('dragging');

      const move = (ev) => {
        shared[id].pos = {
          x: Math.min(maxX, Math.max(minX, start.x + ev.clientX - startX)),
          y: Math.min(maxY, Math.max(minY, start.y + ev.clientY - startY)),
        };
        applyAll(id);
      };
      const up = () => {
        el.classList.remove('dragging');
        window.removeEventListener('mousemove', move);
        window.removeEventListener('mouseup', up);
        save(id, shared[id].pos);
      };
      window.addEventListener('mousemove', move);
      window.addEventListener('mouseup', up);
    });

    handle.addEventListener('dblclick', () => { shared[id].pos = { x: 0, y: 0 }; applyAll(id); save(id, shared[id].pos); });
  });
})();
