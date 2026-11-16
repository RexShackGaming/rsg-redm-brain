import { fetchNui } from "./fetchNui.js";

const app = document.getElementById("app");
const eye = document.getElementById("eye");
const list = document.getElementById("options");

let rows = [];          // rendered option elements, in display order
let selected = -1;      // keyboard / gamepad cursor
let keyboardNav = true;
let gamepadNav = false;
let padRaf = null;

function setTargeted(on) {
  eye.src = on ? "assets/target.png" : "assets/untarget.png";
  eye.classList.toggle("active", on);
}

function activate(el) {
  if (!el) return;
  // focus is dropped after a click, so the hover never releases - block repeat clicks briefly
  el.style.pointerEvents = "none";
  fetchNui("select", [el.targetType, el.targetId, el.zoneId]);
  setTimeout(() => (el.style.pointerEvents = "auto"), 100);
}

function setSelected(i) {
  if (!rows.length) return;
  selected = (i + rows.length) % rows.length;
  rows.forEach((el, n) => el.classList.toggle("selected", n === selected));
  rows[selected].scrollIntoView({ block: "nearest" });
}

function buildRow(entry, quickLabel) {
  const { type, data, id, zoneId } = entry;
  const el = document.createElement("div");
  el.className = "option";
  el.style.animationDelay = `${rows.length * 0.03}s`;

  const icon = document.createElement("span");
  icon.className = "icon";
  const i = document.createElement("i");
  i.className = `fa-fw ${data.icon || "fa-solid fa-hand"}`;
  if (data.iconColor) i.style.color = data.iconColor;
  icon.appendChild(i);

  const label = document.createElement("span");
  label.className = "label";
  label.textContent = data.label ?? "";

  el.append(icon, label);

  if (quickLabel && rows.length === 0) {
    const key = document.createElement("span");
    key.className = "key";
    key.textContent = quickLabel;
    el.appendChild(key);
  }

  el.targetType = type;
  el.targetId = id;
  el.zoneId = zoneId;
  el.addEventListener("click", () => activate(el));
  return el;
}

function renderOptions(data) {
  const entries = [];
  const collect = (type, opt, id, zoneId) => {
    if (!opt.hide) entries.push({ type, data: opt, id, zoneId, order: entries.length });
  };

  if (data.options) {
    for (const type in data.options) {
      data.options[type].forEach((opt, id) => collect(type, opt, id + 1));
    }
  }
  if (data.zones) {
    data.zones.forEach((zone, z) => zone.forEach((opt, id) => collect("zones", opt, id + 1, z + 1)));
  }

  // higher priority first, original order otherwise (matches the quick select target in client.lua)
  entries.sort((a, b) => (b.data.priority || 0) - (a.data.priority || 0) || a.order - b.order);

  rows = [];
  selected = -1;
  for (const entry of entries) {
    const el = buildRow(entry, data.quick);
    list.appendChild(el);
    rows.push(el);
  }
}

const markerLayer = document.getElementById("markers");
const markerPool = [];
let pulse = false;

function renderMarkers(markers, style) {
  if (style) {
    markerLayer.style.setProperty("--marker", style.colour);
    markerLayer.style.setProperty("--marker-active", style.hover);
    markerLayer.style.setProperty("--marker-size", `${style.size}px`);
    pulse = !!style.pulse;
  }

  while (markerPool.length < markers.length) {
    const el = document.createElement("div");
    el.className = "marker";
    el.innerHTML = '<i class="fa-solid fa-eye"></i>';
    markerLayer.appendChild(el);
    markerPool.push(el);
  }

  markerPool.forEach((el, i) => {
    const m = markers[i];
    if (!m) { el.style.display = "none"; return; }
    el.style.display = "block";
    el.style.left = `${m.x * 100}%`;
    el.style.top = `${m.y * 100}%`;
    el.classList.toggle("active", !!m.a);
    el.classList.toggle("pulse", pulse);
  });
}

/* keyboard: only delivered while the menu is focused (Left Mouse) */
window.addEventListener("keydown", (e) => {
  if (app.classList.contains("hidden")) return;

  if (e.key === "Escape") { fetchNui("close"); return; }
  if (!keyboardNav || !rows.length) return;

  if (e.key === "ArrowDown") { e.preventDefault(); setSelected(selected + 1); }
  else if (e.key === "ArrowUp") { e.preventDefault(); setSelected(selected < 0 ? rows.length - 1 : selected - 1); }
  else if (e.key === "Enter" || e.key === " ") { if (selected >= 0) { e.preventDefault(); activate(rows[selected]); } }
  else if (/^[1-9]$/.test(e.key)) { activate(rows[Number(e.key) - 1]); }
});

/* gamepad (experimental): standard mapping, only while the NUI has focus so gameplay buttons never fire */
const padPrev = {};
function pollPad() {
  if (!gamepadNav || app.classList.contains("hidden")) { padRaf = null; return; }

  if (document.hasFocus() && rows.length) {
    const pads = navigator.getGamepads ? navigator.getGamepads() : [];
    for (const pad of pads) {
      if (!pad) continue;
      const edge = (b) => {
        const down = !!(pad.buttons[b] && pad.buttons[b].pressed);
        const was = padPrev[b];
        padPrev[b] = down;
        return down && !was;
      };
      if (edge(13)) setSelected(selected + 1);        // d-pad down
      if (edge(12)) setSelected(selected < 0 ? rows.length - 1 : selected - 1); // d-pad up
      if (edge(0) && selected >= 0) activate(rows[selected]); // A
      if (edge(1)) fetchNui("close");                 // B
    }
  }

  padRaf = requestAnimationFrame(pollPad);
}

window.addEventListener("message", ({ data }) => {
  if (data.event === "markers") {
    renderMarkers(data.markers || [], data.style);
    return;
  }

  list.innerHTML = "";
  rows = [];
  selected = -1;

  switch (data.event) {
    case "visible":
      app.classList.toggle("hidden", !data.state);
      if (!data.state) setTargeted(false);
      return;

    case "leftTarget":
      setTargeted(false);
      return;

    case "setTarget":
      setTargeted(true);
      keyboardNav = data.keyboard !== false;
      gamepadNav = !!data.gamepad;
      renderOptions(data);
      if (gamepadNav && padRaf === null) padRaf = requestAnimationFrame(pollPad);
      return;
  }
});
