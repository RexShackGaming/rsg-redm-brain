import { fetchNui } from "./fetchNui.js";

const app = document.getElementById("app");
const eye = document.getElementById("eye");
const list = document.getElementById("options");

const escapeHtml = (s) =>
  String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

function setTargeted(on) {
  eye.src = on ? "assets/target.png" : "assets/untarget.png";
  eye.classList.toggle("active", on);
}

function onSelect() {
  // focus is dropped after a click, so the hover never releases - block repeat clicks briefly
  this.style.pointerEvents = "none";
  fetchNui("select", [this.targetType, this.targetId, this.zoneId]);
  setTimeout(() => (this.style.pointerEvents = "auto"), 100);
}

let index = 0;

function addOption(type, data, id, zoneId) {
  if (data.hide) return;

  const el = document.createElement("div");
  el.className = "option";
  el.style.animationDelay = `${index++ * 0.03}s`;

  const icon = document.createElement("span");
  icon.className = "icon";
  const i = document.createElement("i");
  i.className = `fa-fw ${data.icon || "fa-solid fa-hand"}`;
  if (data.iconColor) i.style.color = data.iconColor;
  icon.appendChild(i);

  const label = document.createElement("span");
  label.className = "label";
  label.innerHTML = escapeHtml(data.label);

  el.append(icon, label);
  el.targetType = type;
  el.targetId = id;
  el.zoneId = zoneId;
  el.addEventListener("click", onSelect);
  list.appendChild(el);
}

const markerLayer = document.getElementById("markers");
const markerPool = [];

function renderMarkers(markers, style) {
  if (style) {
    markerLayer.style.setProperty("--marker", style.colour);
    markerLayer.style.setProperty("--marker-active", style.hover);
    markerLayer.style.setProperty("--marker-size", `${style.size}px`);
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
    el.classList.toggle("pulse", !!(style && style.pulse));
  });
}

window.addEventListener("message", ({ data }) => {
  if (data.event === "markers") {
    renderMarkers(data.markers || [], data.style);
    return;
  }

  list.innerHTML = "";
  index = 0;

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
      if (data.options) {
        for (const type in data.options) {
          data.options[type].forEach((opt, id) => addOption(type, opt, id + 1));
        }
      }
      if (data.zones) {
        data.zones.forEach((zone, z) => zone.forEach((opt, id) => addOption("zones", opt, id + 1, z + 1)));
      }
      return;
  }
});
