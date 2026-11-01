
const ATTACHMENT_CATEGORY_LABEL_DISPLAY = {
    FRAME_VERTDATA: "FRAME",
};


function sortAttachmentSlotLayout(categories, lists, slotOrder) {
    if (!categories || !categories.length) return { categories: [], lists: lists || [] };
    const listsSafe = lists || [];
    if (!slotOrder || !slotOrder.length) {
        return { categories: categories.slice(), lists: listsSafe.slice() };
    }
    const rank = {};
    for (let i = 0; i < slotOrder.length; i++) {
        rank[String(slotOrder[i])] = i;
    }
    const indices = categories.map(function (_, idx) { return idx; });
    indices.sort(function (a, b) {
        const catA = String(categories[a]);
        const catB = String(categories[b]);
        const ra = rank[catA] != null ? rank[catA] : 1000 + a;
        const rb = rank[catB] != null ? rank[catB] : 1000 + b;
        if (ra !== rb) return ra - rb;
        return catA.localeCompare(catB);
    });
    return {
        categories: indices.map(function (i) { return categories[i]; }),
        lists: indices.map(function (i) { return listsSafe[i] || []; }),
    };
}

function attachmentCategoryLabelForUi(categoryKey) {
    const mapped = ATTACHMENT_CATEGORY_LABEL_DISPLAY[categoryKey];
    return mapped != null ? mapped : categoryKey;
}


function attachmentSlotCategoryKey(layout, slotIndex) {
    if (!layout || !layout.categories) return "";

    const c = layout.categories[slotIndex];
    return c != null ? String(c) : "";
}

let weaponAttachmentsWeapon = null;
let weaponAttachmentsOpen = false;
let weaponAttachmentsPanelSavedPos = null;
let weaponAttachmentsPanelUserDragged = false;

const WEAPON_ATTACHMENTS = {
    UTIL: {
        ATTACHMENT_SLOT_LAYOUT_FROM_CONFIG: function (attachmentComponents, componentCategoryCount, slotOrder) {
            const emptyOut = { categories: [], lists: [], layoutKind: "none" };
            if (!attachmentComponents || typeof attachmentComponents !== "object") return emptyOut;
            const topKeys = Object.keys(attachmentComponents);
            const flatNames = [];
            let nestedLegacy = false;
            let nestedComponentMap = false;

            for (let i = 0; i < topKeys.length; i++) {
                const k = topKeys[i];
                const rows = attachmentComponents[k];
                if (Array.isArray(rows)) {
                    nestedLegacy = true;
                    break;
                }
                if (rows && typeof rows === "object") {
                    const subKeys = Object.keys(rows);
                    let allBool = true;
                    for (let j = 0; j < subKeys.length; j++) {
                        if (rows[subKeys[j]] !== true) {
                            allBool = false;
                            break;
                        }
                    }
                    if (allBool && subKeys.length && subKeys.every(function (s) { return /^COMPONENT_/.test(s); })) {
                        nestedComponentMap = true;
                        break;
                    }
                }
            }

            if (nestedLegacy) {
                const categories = topKeys.slice();
                const lists = [];
                for (let k = 0; k < categories.length; k++) {
                    const rows = attachmentComponents[categories[k]];
                    const names = [];
                    if (Array.isArray(rows)) {
                        for (let i = 0; i < rows.length; i++) {
                            const r = rows[i];
                            if (r && r.ITEM_NAME != null) names.push(String(r.ITEM_NAME));
                        }
                    }
                    lists.push(names);
                }
                const sortedLegacy = sortAttachmentSlotLayout(categories, lists, slotOrder);
                return {
                    categories: sortedLegacy.categories,
                    lists: sortedLegacy.lists,
                    layoutKind: "nestedLegacy",
                };
            }

            if (nestedComponentMap) {
                const categories = topKeys.slice();
                const lists = [];
                for (let k = 0; k < categories.length; k++) {
                    const rows = attachmentComponents[categories[k]];
                    const names = [];
                    if (rows && typeof rows === "object") {
                        const sk = Object.keys(rows).sort();
                        for (let j = 0; j < sk.length; j++) {
                            if (rows[sk[j]] === true) names.push(sk[j]);
                        }
                    }
                    lists.push(names);
                }
                const sortedMap = sortAttachmentSlotLayout(categories, lists, slotOrder);
                return {
                    categories: sortedMap.categories,
                    lists: sortedMap.lists,
                    layoutKind: "nestedMap",
                };
            }

            for (let i = 0; i < topKeys.length; i++) {
                if (attachmentComponents[topKeys[i]] === true && /^COMPONENT_/.test(topKeys[i])) {
                    flatNames.push(topKeys[i]);
                }
            }
            if (!flatNames.length) return emptyOut;

            flatNames.sort();
            let slotN = Number(componentCategoryCount);
            if (!Number.isFinite(slotN) || slotN < 1) slotN = 1;
            const pool = flatNames.slice();
            const categories = [];
            const lists = [];
            for (let s = 0; s < slotN; s++) {
                categories.push("Part " + (s + 1));
                lists.push(pool.slice());
            }
            return { categories, lists, layoutKind: "flatPools" };
        },

        EFFECTIVE_SLOT_LAYOUT: function (weapon) {
            if (!weapon) return { categories: [], lists: [], layoutKind: "none" };

            return WEAPON_ATTACHMENTS.UTIL.ATTACHMENT_SLOT_LAYOUT_FROM_CONFIG(weapon.attachmentComponents, weapon.componentCategoryCount, weapon.attachmentSlotOrder);
        },

        EFFECTIVE_SLOT_ALLOWLISTS: function (weapon) {
            const L = WEAPON_ATTACHMENTS.UTIL.EFFECTIVE_SLOT_LAYOUT(weapon);
            return L.lists || [];
        },

        SLOT_COUNT: function (weapon) {
            if (!weapon) return 0;
            const ly = WEAPON_ATTACHMENTS.UTIL.EFFECTIVE_SLOT_LAYOUT(weapon);
            if (ly.categories && ly.categories.length) return ly.categories.length;
            if (ly.lists && ly.lists.length) return ly.lists.length;
            const n = Number(weapon.componentCategoryCount);
            return Number.isFinite(n) && n > 0 ? n : 0;
        },

        POST: function (event, payload) {
            $.post(`https://${GetParentResourceName()}/${event}`, JSON.stringify(payload || {}));
        },

        ITEM_ALLOWED_IN_SLOT: function (itemName, slotIndex) {
            const lists =
                weaponAttachmentsWeapon && WEAPON_ATTACHMENTS.UTIL.EFFECTIVE_SLOT_ALLOWLISTS(weaponAttachmentsWeapon);
            if (!lists || slotIndex < 0 || slotIndex >= lists.length) return false;
            const allowed = lists[slotIndex];
            if (!Array.isArray(allowed)) return false;
            const n = String(itemName);
            for (let i = 0; i < allowed.length; i++) {
                if (allowed[i] === n) return true;
            }
            return false;
        },

        SLOT_IS_OCCUPIED: function (weapon, slotIndex) {
            if (!weapon || typeof slotIndex !== "number" || slotIndex < 0) return false;
            const resolved = WEAPON_ATTACHMENTS.UTIL.RESOLVED_SLOT_PARTS(weapon);
            const parts = resolved.slotParts || [];
            const p = parts[slotIndex];
            return p != null && String(p) !== "";
        },

        RESOLVED_SLOT_PARTS: function (weapon) {
            const layout = WEAPON_ATTACHMENTS.UTIL.EFFECTIVE_SLOT_LAYOUT(weapon);
            const lists = layout.lists || [];
            const categories = layout.categories || [];
            const n = Math.max(categories.length, lists.length);
            const comps = weapon && weapon.components;
            const lk = layout.layoutKind;
            const slotParts = [];
            if (!n) return { layout, slotParts };

            if (lk === "flatPools" || lk === "nestedLegacy") {
                const list = Array.isArray(comps) ? comps.slice() : [];
                const assigned = WEAPON_ATTACHMENTS.UTIL.ASSIGN_COMPONENTS_TO_SLOTS(list, lists, n);
                for (let i = 0; i < n; i++) slotParts.push(assigned[i] || null);
                return { layout, slotParts };
            }

            if (lk === "nestedMap") {
                const map = comps && typeof comps === "object" && !Array.isArray(comps) ? comps : {};
                for (let i = 0; i < n; i++) {
                    const cat = categories[i];
                    const raw = cat != null ? map[cat] : null;
                    const v = raw != null ? String(raw) : "";
                    slotParts.push(v !== "" ? v : null);
                }
                return { layout, slotParts };
            }

            return { layout, slotParts };
        },

        ASSIGN_COMPONENTS_TO_SLOTS: function (components, allowlists, maxSlots) {
            const list = Array.isArray(components) ? components.slice() : [];
            const used = new Set();
            const perSlot = [];
            for (let i = 0; i < maxSlots; i++) {
                const allowed = allowlists[i];
                const set = allowed && allowed.length ? new Set(allowed) : null;
                let found = null;
                if (set) {
                    for (let j = 0; j < list.length; j++) {
                        const c = list[j];
                        if (used.has(c)) continue;
                        if (set.has(c)) {
                            found = c;
                            break;
                        }
                    }
                }
                if (found) used.add(found);
                perSlot.push(found);
            }
            return perSlot;
        },

        MERGE_COMPONENT_FOR_SLOT: function (components, slotIndex, newName, allowlists) {
            if (!Array.isArray(allowlists) || slotIndex < 0 || slotIndex >= allowlists.length) {
                return Array.isArray(components) ? components.slice() : [];
            }
            const allowed = allowlists[slotIndex];
            if (!Array.isArray(allowed) || !allowed.length) return Array.isArray(components) ? components.slice() : [];
            const allow = new Set(allowed);
            const n = String(newName);
            if (!allow.has(n)) return Array.isArray(components) ? components.slice() : [];

            const maxSlots = allowlists.length;
            const list = Array.isArray(components) ? components.slice() : [];
            const assigned = WEAPON_ATTACHMENTS.UTIL.ASSIGN_COMPONENTS_TO_SLOTS(list, allowlists, maxSlots);
            const oldAt = assigned[slotIndex];
            let base = list.filter(function (c) {
                return String(c) !== n;
            });
            if (oldAt) base = base.filter(function (c) {
                return String(c) !== String(oldAt);
            });
            base.push(n);
            return base;
        },

        MERGE_ON_DROP: function (weapon, slotIndex, itemName) {
            if (!weapon) return;
            const layout = WEAPON_ATTACHMENTS.UTIL.EFFECTIVE_SLOT_LAYOUT(weapon);
            const lk = layout.layoutKind;
            const lists = layout.lists || [];
            const categories = layout.categories || [];
            const n = String(itemName);

            if (lk === "flatPools" || lk === "nestedLegacy") {
                if (!Array.isArray(weapon.components)) weapon.components = [];
                weapon.components = WEAPON_ATTACHMENTS.UTIL.MERGE_COMPONENT_FOR_SLOT(
                    weapon.components,
                    slotIndex,
                    n,
                    lists
                );
                return;
            }

            if (lk !== "nestedMap") return;
            const cat = categories[slotIndex];
            if (cat == null) return;
            const allowed = lists[slotIndex];
            if (!Array.isArray(allowed) || !allowed.length || !allowed.includes(n)) return;
            const prevMap =
                weapon.components && typeof weapon.components === "object" && !Array.isArray(weapon.components)
                    ? weapon.components
                    : {};
            weapon.components = Object.assign({}, prevMap);
            weapon.components[cat] = n;
        },

        REMOVE_INSTALLED_COMPONENT: function (weapon, slotIndex, itemName) {
            if (!weapon) return;
            const layout = WEAPON_ATTACHMENTS.UTIL.EFFECTIVE_SLOT_LAYOUT(weapon);
            const lk = layout.layoutKind;
            const lists = layout.lists || [];
            const categories = layout.categories || [];
            const s = String(itemName);

            if (lk === "flatPools" || lk === "nestedLegacy") {
                if (!Array.isArray(weapon.components)) weapon.components = [];
                weapon.components = weapon.components.filter(function (c) {
                    return String(c) !== s;
                });
                return;
            }

            if (lk !== "nestedMap") return;
            const cat = categories[slotIndex];
            if (cat == null) return;

            const map = weapon.components && typeof weapon.components === "object" && !Array.isArray(weapon.components) ? Object.assign({}, weapon.components) : {};
            if (map[cat] != null && String(map[cat]) === s) {
                delete map[cat];
            }
            weapon.components = map;
        },

        SLOT_LABEL_AT: function (layout, slotIndex) {
            const categories = layout && layout.categories ? layout.categories : [];
            const c = categories[slotIndex];
            if (c == null || String(c) === "") return "";
            return attachmentCategoryLabelForUi(c);
        },
    },

    CHIP_RETURN_TO_MAIN: function (itemName, slotCategory, slotIndex) {
        if (!weaponAttachmentsWeapon || itemName == null || itemName === "") return;
        const s = String(itemName);
        const ly = WEAPON_ATTACHMENTS.UTIL.EFFECTIVE_SLOT_LAYOUT(weaponAttachmentsWeapon);
        let cat = slotCategory != null ? String(slotCategory) : "";
        if (!cat && typeof slotIndex === "number" && !Number.isNaN(slotIndex) && slotIndex >= 0) {
            cat = attachmentSlotCategoryKey(ly, slotIndex);
        }
        WEAPON_ATTACHMENTS.UTIL.POST("removeWeaponAttachment", {
            id: weaponAttachmentsWeapon.id,
            component: s,
            itemName: s,
            slotCategory: cat,
        });
        WEAPON_ATTACHMENTS.UTIL.REMOVE_INSTALLED_COMPONENT(weaponAttachmentsWeapon, slotIndex, s);
        setTimeout(function () {
            WEAPON_ATTACHMENTS.PANEL.RENDER_FULL();
        }, 0);
    },

    DND: {
        TEARDOWN: function () {
            const $wSlot = $("#weaponAttachmentsWeaponSlot");
            if ($wSlot.length && $wSlot.data("ui-droppable")) {
                try {
                    $wSlot.droppable("destroy");
                } catch (e) {
                    /* ignore */
                }
            }
            const $slots = $("#weaponAttachmentsSlots");
            $slots.find(".weapon-attachment-slot").each(function () {
                const $s = $(this);
                if ($s.data("ui-droppable")) {
                    try {
                        $s.droppable("destroy");
                    } catch (e) {
                        /* ignore */
                    }
                }
                $s.find(".weapon-attachment-chip").each(function () {
                    const $c = $(this);
                    if ($c.data("ui-draggable")) {
                        try {
                            $c.draggable("destroy");
                        } catch (e) {
                            /* ignore */
                        }
                    }
                });
            });
        },

        BIND_SLOTS: function () {
            $("#weaponAttachmentsSlots .weapon-attachment-slot").each(function () {
                const $slot = $(this);
                const slotIdx = parseInt($slot.attr("data-index"), 10);
                if ($slot.data("ui-droppable")) {
                    try {
                        $slot.droppable("destroy");
                    } catch (e) {
                        /* ignore */
                    }
                }
                $slot.droppable({
                    tolerance: "pointer",
                    greedy: true,
                    accept: function ($dr) {
                        if (!weaponAttachmentsWeapon) return false;
                        if (!$dr.closest("#inventoryElement").length || !$dr.hasClass("item")) return false;
                        const it = $dr.data("item");
                        if (!it) return false;
                        const n = it.name != null ? String(it.name) : "";
                        if (!WEAPON_ATTACHMENTS.UTIL.ITEM_ALLOWED_IN_SLOT(n, slotIdx)) return false;
                        if (WEAPON_ATTACHMENTS.UTIL.SLOT_IS_OCCUPIED(weaponAttachmentsWeapon, slotIdx)) return false;
                        return true;
                    },
                    drop: function (_ev, ui) {
                        if (disabled) return;
                        const $dr = $(ui.draggable);
                        const it = $dr.data("item");
                        if (!it || !weaponAttachmentsWeapon) return;
                        const itemName = it.name != null ? String(it.name) : null;
                        if (!itemName || !WEAPON_ATTACHMENTS.UTIL.ITEM_ALLOWED_IN_SLOT(itemName, slotIdx)) return;
                        if (WEAPON_ATTACHMENTS.UTIL.SLOT_IS_OCCUPIED(weaponAttachmentsWeapon, slotIdx)) return;

                        /* Main inv. draggable reverts unless invDropAccepted (see invScript / secondaryInvScript). */
                        $dr.data("invDropAccepted", true);

                        const ly = WEAPON_ATTACHMENTS.UTIL.EFFECTIVE_SLOT_LAYOUT(weaponAttachmentsWeapon);
                        const cat = attachmentSlotCategoryKey(ly, slotIdx);
                        const itemId = it.id != null ? it.id : null;

                        WEAPON_ATTACHMENTS.UTIL.POST("addWeaponAttachment", {
                            id: weaponAttachmentsWeapon.id,
                            component: itemName,
                            slotCategory: cat,
                            itemId: itemId,
                        });
                        WEAPON_ATTACHMENTS.UTIL.MERGE_ON_DROP(weaponAttachmentsWeapon, slotIdx, itemName);
                        setTimeout(function () {
                            WEAPON_ATTACHMENTS.PANEL.RENDER_FULL();
                        }, 0);
                    },
                });
            });
        },

        BUILD_CHIP_DRAG_HELPER: function ($chip) {
            const $slot = $chip.closest(".weapon-attachment-slot");
            const slotW = $slot.length ? $slot.outerWidth() : 48;
            const slotH = $slot.length ? $slot.outerHeight() : 48;
            const itemName = $chip.data("itemName");

            return $("<div/>")
                .addClass(
                    "weapon-attachment-drag-helper weapon-attachment-slot item item-filled weapon-attachment-slot--filled"
                )
                .css({ width: slotW, height: slotH })
                .append(
                    $("<div/>")
                        .addClass("weapon-attachment-chip")
                        .append(
                            $("<span/>")
                                .addClass("weapon-attachment-chip-icon item-inv-icon")
                                .attr(
                                    "style",
                                    UTILS.INVENTORY_SLOT_BACKGROUND_STYLE(
                                        imageCache[itemName],
                                        "contain",
                                        "",
                                        ""
                                    )
                                )
                        )
                );
        },

        BIND_CHIP: function ($chip) {
            $chip.draggable({
                helper: function () {
                    return WEAPON_ATTACHMENTS.DND.BUILD_CHIP_DRAG_HELPER($chip);
                },
                appendTo: "body",
                zIndex: 99999,
                scroll: false,
                distance: 8,
                containment: "document",
                revert: "invalid",
                drag: function (event) {
                    INVENTORY.MAIN.MAIN_INV_AUTO_SCROLL_DRAG(event);
                    const ev = event.originalEvent || event;
                    const x = ev.clientX;
                    const y = ev.clientY;
                    $chip.data("invAttachmentPointer", { x: x, y: y });
                },
                start: function () {
                    $(".tooltip").remove();
                    $chip.find(".item-inv-icon").first().css("opacity", 0.35);
                },
                stop: function () {
                    $chip.find(".item-inv-icon").first().css("opacity", "");
                },
            });
        },

        BIND_WEAPON_SLOT: function () {
            const $slot = $("#weaponAttachmentsWeaponSlot");
            if (!$slot.length) return;
            if ($slot.data("ui-droppable")) {
                try {
                    $slot.droppable("destroy");
                } catch (e) {
                    /* ignore */
                }
            }
            $slot.droppable({
                tolerance: "pointer",
                greedy: true,
                accept: function ($dr) {
                    if (!$dr.closest("#inventoryElement").length || !$dr.hasClass("item")) return false;
                    const it = $dr.data("item");
                    if (!it || it.type !== "item_weapon") return false;
                    const n = Number(it.componentCategoryCount);
                    return Number.isFinite(n) && n > 0;
                },
                drop: function (_ev, ui) {
                    if (disabled) return;
                    const $dr = $(ui.draggable);
                    const it = $dr.data("item");
                    if (!it || it.type !== "item_weapon") return;
                    $dr.data("invDropAccepted", true);
                    WEAPON_ATTACHMENTS.SET_WEAPON_FROM_ITEM(it);
                },
            });
        },

    },

    PANEL: {
        PLACE_BESIDE_INVENTORY: function () {
            const $panel = $("#weaponAttachmentsPanel");
            if (!$panel.length || !$panel.is(":visible")) return;

            const margin = 12;
            const dockGap = 12;
            const topOffset = 34;
            const main = document.getElementById("inventoryElement");
            const second = document.getElementById("secondInventoryElement");
            const hud = document.getElementById("inventoryHud");
            let left;
            let top;

            if (main) {
                const mainRect = main.getBoundingClientRect();
                const secondRect = second ? second.getBoundingClientRect() : null;
                const secondVisible =
                    second &&
                    $("#secondInventoryElement").is(":visible") &&
                    secondRect &&
                    secondRect.width > 0 &&
                    secondRect.height > 0;
                const pw = $panel.outerWidth() || Math.round(window.innerWidth * 0.17) || 200;
                const ph = $panel.outerHeight() || 200;
                if (mainRect.width > 2 && mainRect.height > 2) {
                    if (secondVisible) {
                        const gapCenter = (mainRect.right + secondRect.left) / 2;
                        left = gapCenter - pw / 2;
                    } else {
                        left = mainRect.right + dockGap;
                    }
                    top = mainRect.top + (mainRect.height - ph) / 2 - topOffset;
                }
            }

            if ((left == null || top == null) && hud) {
                const st = window.getComputedStyle(hud);
                if (st.display !== "none" && st.visibility !== "hidden") {
                    const r = hud.getBoundingClientRect();
                    if (r.width > 2 && r.height > 2) {
                        const pw = $panel.outerWidth() || Math.round(window.innerWidth * 0.17) || 200;
                        left = r.right + dockGap;
                        top = Math.max(margin, r.top);
                        if (left + pw > window.innerWidth - margin) {
                            left = Math.max(margin, r.left - pw - dockGap);
                        }
                    }
                }
            }

            if (left == null || top == null) {
                const pw = $panel.outerWidth() || Math.round(window.innerWidth * 0.17) || 200;
                left = Math.max(margin, window.innerWidth - margin - pw);
                top = window.innerHeight * 0.12;
            }

            $panel.css({
                position: "fixed",
                left: Math.round(left),
                top: Math.round(top),
                transform: "none",
                right: "auto",
                bottom: "auto",
                zIndex: 11950,
            });
        },

        CLAMP_TO_WINDOW: function () {
            const $panel = $("#weaponAttachmentsPanel");
            if (!$panel.length || !$panel.is(":visible")) return;
            let left = parseFloat($panel.css("left"));
            let top = parseFloat($panel.css("top"));
            if (!Number.isFinite(left)) left = 0;
            if (!Number.isFinite(top)) top = 0;
            const w = $panel.outerWidth() || 200;
            const h = $panel.outerHeight() || 200;
            const maxL = Math.max(0, window.innerWidth - w);
            const maxT = Math.max(0, window.innerHeight - h);
            left = Math.min(Math.max(0, left), maxL);
            top = Math.min(Math.max(0, top), maxT);
            left = Math.round(left);
            top = Math.round(top);
            $panel.css({ left: left, top: top, transform: "none" });
            if (weaponAttachmentsPanelUserDragged) {
                weaponAttachmentsPanelSavedPos = { left: left, top: top };
            }
        },

        DESTROY_DRAGGABLE: function () {
            const $panel = $("#weaponAttachmentsPanel");
            if ($panel.data("ui-draggable")) {
                try {
                    $panel.draggable("destroy");
                } catch (_e) {
                    /* ignore */
                }
            }
        },

        INIT_DRAGGABLE: function () {
            const $panel = $("#weaponAttachmentsPanel");
            if (!$panel.length || !$.fn.draggable) return;
            if ($panel.data("ui-draggable")) return;
            $panel.draggable({
                handle: ".weapon-attachments-panel-head",
                cancel: ".weapon-attachments-panel-close,button",
                containment: "window",
                scroll: false,
                stop: function () {
                    const $p = $(this);
                    weaponAttachmentsPanelUserDragged = true;
                    weaponAttachmentsPanelSavedPos = {
                        left: Math.round(parseFloat($p.css("left")) || 0),
                        top: Math.round(parseFloat($p.css("top")) || 0),
                    };
                },
            });
        },

        RENDER_WEAPON_ZONE: function () {
            const $wrap = $("#weaponAttachmentsWeaponImg");
            $wrap.empty();
            const $slot = $("<div/>")
                .attr("id", "weaponAttachmentsWeaponSlot")
                .addClass("weapon-attachments-weapon-slot item");
            if (!weaponAttachmentsWeapon) {
                $slot.addClass("weapon-attachments-weapon-slot--empty");
                const hint =
                    (LANGUAGE && LANGUAGE.attachmentsDragWeaponHint) || "Drag a weapon here";
                $slot.append($("<span/>").addClass("weapon-attachments-weapon-slot__hint").text(hint));
            } else {
                $slot.addClass("weapon-attachments-weapon-slot--filled item-filled");
                const $drag = $("<div/>")
                    .addClass("weapon-attachments-weapon-drag")
                    .attr("title", weaponAttachmentsWeapon.label || weaponAttachmentsWeapon.name || "");
                $drag.append(
                    $("<span/>")
                        .addClass("weapon-attachments-weapon-drag-icon item-inv-icon")
                        .attr(
                            "style",
                            UTILS.INVENTORY_SLOT_BACKGROUND_STYLE(
                                imageCache[weaponAttachmentsWeapon.name],
                                "contain",
                                "",
                                ""
                            )
                        )
                );
                $slot.append($drag);
            }
            $wrap.append($slot);
            WEAPON_ATTACHMENTS.DND.BIND_WEAPON_SLOT();
        },

        RENDER_COMPONENT_SLOTS: function () {
            const $wrap = $("#weaponAttachmentsSlots");
            $wrap.empty();
            if (!weaponAttachmentsWeapon) return;

            const resolved = WEAPON_ATTACHMENTS.UTIL.RESOLVED_SLOT_PARTS(weaponAttachmentsWeapon);
            const layout = resolved.layout;
            const slotComps = resolved.slotParts;
            const maxSlots = slotComps.length;

            for (let i = 0; i < maxSlots; i++) {
                const itemName = slotComps[i] || null;
                const slotLabel = WEAPON_ATTACHMENTS.UTIL.SLOT_LABEL_AT(layout, i);

                const $col = $("<div/>")
                    .addClass("weapon-attachment-slot-wrap")
                    .appendTo($wrap);

                if (slotLabel) {
                    $col.append(
                        $("<div/>")
                            .addClass("weapon-attachment-slot__label")
                            .text(slotLabel)
                    );
                }

                const $slot = $("<div/>")
                    .addClass("weapon-attachment-slot item")
                    .attr("data-index", String(i))
                    .appendTo($col);

                if (itemName) {
                    $slot.addClass("item-filled weapon-attachment-slot--filled");
                    const catStr = attachmentSlotCategoryKey(layout, i);

                    const $chip = $("<div/>")
                        .addClass("weapon-attachment-chip")
                        .attr("data-item-name", itemName)
                        .attr("data-slot-index", String(i))
                        .attr("data-slot-category", catStr)
                        .data("itemName", itemName)
                        .data("slotIndex", i)
                        .data("slotCategory", catStr)
                        .attr("title", itemName);

                    $chip.append(
                        $("<span/>")
                            .addClass("weapon-attachment-chip-icon item-inv-icon")
                            .attr(
                                "style",
                                UTILS.INVENTORY_SLOT_BACKGROUND_STYLE(imageCache[itemName], "contain", "", "")
                            )
                    );

                    $slot.append($chip);
                    WEAPON_ATTACHMENTS.DND.BIND_CHIP($chip);
                } else {
                    $slot.addClass("weapon-attachment-slot--empty");
                }
            }

            WEAPON_ATTACHMENTS.DND.BIND_SLOTS();
        },

        RENDER_FULL: function () {
            WEAPON_ATTACHMENTS.DND.TEARDOWN();
            $("#weaponAttachmentsSlots").empty();
            WEAPON_ATTACHMENTS.PANEL.RENDER_WEAPON_ZONE();
            WEAPON_ATTACHMENTS.PANEL.RENDER_COMPONENT_SLOTS();
            $("#weaponAttachmentsSlotsLabel").prop("hidden", !weaponAttachmentsWeapon);
        },
    },

    UPDATE_STATIC_LABELS: function () {
        const $slotsLbl = $("#weaponAttachmentsSlotsLabel");
        const $foot = $("#weaponAttachmentsFooter");
        const $rz = $("#weaponAttachmentsRemoveZone");
        if ($slotsLbl.length) {
            $slotsLbl.text(LANGUAGE.attachmentsPartsTitle);
        }
        if ($foot.length) {
            $foot.text(LANGUAGE.attachmentsFooterHint);
        }
        if ($rz.length) {
            $rz.hide().empty();
        }
    },

    SHOW_PANEL: function () {
        weaponAttachmentsOpen = true;
        const $panel = $("#weaponAttachmentsPanel");
        $panel.removeClass("weapon-attachments-panel--hidden").attr("aria-hidden", "false");
        $panel.css({ transform: "none", right: "auto", bottom: "auto" });

        WEAPON_ATTACHMENTS.PANEL.DESTROY_DRAGGABLE();
        if (weaponAttachmentsPanelUserDragged && weaponAttachmentsPanelSavedPos) {
            $panel.css({
                position: "fixed",
                left: weaponAttachmentsPanelSavedPos.left,
                top: weaponAttachmentsPanelSavedPos.top,
                zIndex: 11950,
            });
        } else {
            WEAPON_ATTACHMENTS.PANEL.PLACE_BESIDE_INVENTORY();
        }
        WEAPON_ATTACHMENTS.PANEL.CLAMP_TO_WINDOW();
        WEAPON_ATTACHMENTS.PANEL.INIT_DRAGGABLE();
    },

    OPEN_EMPTY: function () {
        weaponAttachmentsWeapon = null;
        $("#weaponAttachmentsTitle").text(
            (LANGUAGE && LANGUAGE.attachmentsTitle) || "Attachments"
        );
        WEAPON_ATTACHMENTS.UPDATE_STATIC_LABELS();
        WEAPON_ATTACHMENTS.SHOW_PANEL();
        WEAPON_ATTACHMENTS.PANEL.RENDER_FULL();
        $("#weaponAttachmentsOpenBtn").attr("aria-expanded", "true");
    },

    TOGGLE_FROM_UI: function () {
        if (weaponAttachmentsOpen && !$("#weaponAttachmentsPanel").hasClass("weapon-attachments-panel--hidden")) {
            WEAPON_ATTACHMENTS.CLOSE();
            return;
        }
        WEAPON_ATTACHMENTS.OPEN_EMPTY();
    },

    SET_WEAPON_FROM_ITEM: function (item) {
        if (!item || item.type !== "item_weapon") return;
        let compsStore = {};
        const rawComp = item.components;
        if (Array.isArray(rawComp)) compsStore = rawComp.slice();
        else if (rawComp != null && typeof rawComp === "object") compsStore = $.extend({}, rawComp);

        weaponAttachmentsWeapon = {
            id: item.id,
            name: item.name,
            label: item.label,
            type: item.type,
            components: compsStore,
            componentCategoryCount: item.componentCategoryCount,
            attachmentComponents: item.attachmentComponents && typeof item.attachmentComponents === "object" ? item.attachmentComponents : null,
            attachmentSlotOrder: Array.isArray(item.attachmentSlotOrder) ? item.attachmentSlotOrder.slice() : null,
        };
        const label = weaponAttachmentsWeapon.label || weaponAttachmentsWeapon.name || "";
        $("#weaponAttachmentsTitle").text(label);
        WEAPON_ATTACHMENTS.UPDATE_STATIC_LABELS();
        if (!weaponAttachmentsOpen) {
            WEAPON_ATTACHMENTS.SHOW_PANEL();
        }
        WEAPON_ATTACHMENTS.PANEL.RENDER_FULL();
        $("#weaponAttachmentsOpenBtn").attr("aria-expanded", "true");
    },

    WEAPON_CLEAR_TO_MAIN: function () {
        weaponAttachmentsWeapon = null;
        $("#weaponAttachmentsTitle").text(
            (LANGUAGE && LANGUAGE.attachmentsTitle) || "Attachments"
        );
        WEAPON_ATTACHMENTS.UPDATE_STATIC_LABELS();
        WEAPON_ATTACHMENTS.PANEL.RENDER_FULL();
    },

    OPEN: function (weapon) {
        if (!weapon) return;
        WEAPON_ATTACHMENTS.SET_WEAPON_FROM_ITEM(weapon);
    },

    CLOSE: function () {
        weaponAttachmentsOpen = false;
        weaponAttachmentsWeapon = null;
        WEAPON_ATTACHMENTS.DND.TEARDOWN();
        $("#weaponAttachmentsSlots").empty();
        $("#weaponAttachmentsWeaponImg").empty();
        WEAPON_ATTACHMENTS.PANEL.DESTROY_DRAGGABLE();
        $("#weaponAttachmentsPanel")
            .addClass("weapon-attachments-panel--hidden")
            .attr("aria-hidden", "true");
        $("#weaponAttachmentsOpenBtn").attr("aria-expanded", "false");
    },

    MAIN_ITEM_UPDATE: function (item) {
        if (!weaponAttachmentsOpen || !weaponAttachmentsWeapon || !item || item.type !== "item_weapon")
            return;
        if (Number(item.id) !== Number(weaponAttachmentsWeapon.id)) return;
        const rc = item.components;
        if (Array.isArray(rc)) weaponAttachmentsWeapon.components = rc.slice();
        else if (rc != null && typeof rc === "object") weaponAttachmentsWeapon.components = $.extend({}, rc);
        else weaponAttachmentsWeapon.components = {};
        if (item.componentCategoryCount != null) {
            weaponAttachmentsWeapon.componentCategoryCount = item.componentCategoryCount;
        }
        if (item.attachmentComponents && typeof item.attachmentComponents === "object") {
            weaponAttachmentsWeapon.attachmentComponents = item.attachmentComponents;
        }
        setTimeout(function () {
            WEAPON_ATTACHMENTS.PANEL.RENDER_FULL();
        }, 0);
    },

    IS_OPEN: function () {
        return weaponAttachmentsOpen;
    },
};

window.addEventListener("message", function (ev) {
    if (ev.data && ev.data.action === "initiate") {
        setTimeout(function () {
            WEAPON_ATTACHMENTS.UPDATE_STATIC_LABELS();
        }, 0);
    }
});

$(document).ready(function () {
    const closeClickNs = "click.weaponAttachmentsClose";
    $("#weaponAttachmentsClose")
        .off(closeClickNs)
        .on(closeClickNs, function () {
            WEAPON_ATTACHMENTS.CLOSE();
        });

    $("#weaponAttachmentsOpenBtn")
        .off("click.weaponAttachmentsToolbar")
        .on("click.weaponAttachmentsToolbar", function () {
            if ($(this).prop("disabled")) return;
            WEAPON_ATTACHMENTS.TOGGLE_FROM_UI();
        });

    $(window).on("resize.weaponAttachmentsPanel", function () {
        if (
            weaponAttachmentsOpen &&
            $("#weaponAttachmentsPanel").length &&
            !$("#weaponAttachmentsPanel").hasClass("weapon-attachments-panel--hidden")
        ) {
            WEAPON_ATTACHMENTS.PANEL.CLAMP_TO_WINDOW();
        }
    });
});
