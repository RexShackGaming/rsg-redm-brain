(function () {
    "use strict";

    const resourceName = (window.GetParentResourceName && window.GetParentResourceName()) || "rsg-character";

    const app = document.getElementById("app");
    const menuPanel = document.getElementById("menu-panel");
    const menuTitle = document.getElementById("menu-title");
    const menuSubtitle = document.getElementById("menu-subtitle");
    const menuList = document.getElementById("menu-list");
    const btnBack = document.getElementById("btn-back");

    const dialogModal = document.getElementById("dialog-modal");
    const dialogTitle = document.getElementById("dialog-title");
    const dialogFields = document.getElementById("dialog-fields");
    const dialogSubmit = document.getElementById("dialog-submit");
    const dialogCancel = document.getElementById("dialog-cancel");

    const alertModal = document.getElementById("alert-modal");
    const alertTitle = document.getElementById("alert-title");
    const alertConfirm = document.getElementById("alert-confirm");
    const alertCancel = document.getElementById("alert-cancel");

    const charInfoPanel = document.getElementById("char-info-panel");
    const charInfoName = document.getElementById("char-info-name");
    const charInfoRows = document.getElementById("char-info-rows");
    const charInfoJobLabel = document.getElementById("char-info-job-label");
    const charInfoJob = document.getElementById("char-info-job");
    const charInfoBirthdateLabel = document.getElementById("char-info-birthdate-label");
    const charInfoBirthdate = document.getElementById("char-info-birthdate");
    const charInfoNationalityLabel = document.getElementById("char-info-nationality-label");
    const charInfoNationality = document.getElementById("char-info-nationality");
    const charInfoCashLabel = document.getElementById("char-info-cash-label");
    const charInfoCash = document.getElementById("char-info-cash");
    const charInfoDescEl = document.getElementById("char-info-desc");
    const charInfoGenderRow = document.getElementById("char-info-gender");
    const charInfoGenderMale = document.getElementById("char-info-gender-male");
    const charInfoGenderFemale = document.getElementById("char-info-gender-female");
    const charInfoPlay = document.getElementById("char-info-play");
    const charInfoDelete = document.getElementById("char-info-delete");

    const loadingScreen = document.getElementById("loading-screen");
    const loadingText = document.getElementById("loading-text");

    const spawnSelectPanel = document.getElementById("spawn-select-panel");
    const spawnSelectTitle = document.getElementById("spawn-select-title");
    const spawnSelectSubtitle = document.getElementById("spawn-select-subtitle");
    const spawnSelectCards = document.getElementById("spawn-select-cards");

    const cameraMoveBar = document.getElementById("camera-move-bar");
    const camUpBtn = document.getElementById("cam-up");
    const camDownBtn = document.getElementById("cam-down");
    const camZoomInBtn = document.getElementById("cam-zoom-in");
    const camZoomOutBtn = document.getElementById("cam-zoom-out");
    const camRotateLeftBtn = document.getElementById("cam-rotate-left");
    const camRotateRightBtn = document.getElementById("cam-rotate-right");
    const camRotateLabel = document.getElementById("cam-rotate-label");
    const camHeightLabel = document.getElementById("cam-height-label");
    const camZoomLabel = document.getElementById("cam-zoom-label");
    const camResetBtn = document.getElementById("cam-reset");
    const camResetLabel = document.getElementById("cam-reset-label");
    const descTotalLabel = document.getElementById("desc-total-label");

    let currentElements = [];

    let charInfoPlayLabel = "Play";
    let charInfoCreateLabel = "Create";

    function applyLocale(msg) {
        const s = (msg && msg.strings) || {};
        if (typeof s.back === "string") btnBack.title = s.back;
        if (s.camera) {
            if (camRotateLabel && typeof s.camera.rotate === "string") camRotateLabel.textContent = s.camera.rotate;
            if (camHeightLabel && typeof s.camera.height === "string") camHeightLabel.textContent = s.camera.height;
            if (camZoomLabel && typeof s.camera.zoom === "string") camZoomLabel.textContent = s.camera.zoom;
            if (camRotateLeftBtn && typeof s.camera.rotateLeftTitle === "string") camRotateLeftBtn.title = s.camera.rotateLeftTitle;
            if (camRotateRightBtn && typeof s.camera.rotateRightTitle === "string") camRotateRightBtn.title = s.camera.rotateRightTitle;
            if (camUpBtn && typeof s.camera.upTitle === "string") camUpBtn.title = s.camera.upTitle;
            if (camDownBtn && typeof s.camera.downTitle === "string") camDownBtn.title = s.camera.downTitle;
            if (camZoomInBtn && typeof s.camera.zoomInTitle === "string") camZoomInBtn.title = s.camera.zoomInTitle;
            if (camZoomOutBtn && typeof s.camera.zoomOutTitle === "string") camZoomOutBtn.title = s.camera.zoomOutTitle;
            if (camResetLabel && typeof s.camera.reset === "string") camResetLabel.textContent = s.camera.reset;
            if (camResetBtn && typeof s.camera.resetTitle === "string") camResetBtn.title = s.camera.resetTitle;
        }
        if (descTotalLabel && typeof s.total === "string") descTotalLabel.textContent = s.total;
        if (s.charInfo) {
            if (charInfoJobLabel && typeof s.charInfo.job === "string") charInfoJobLabel.textContent = s.charInfo.job;
            if (charInfoBirthdateLabel && typeof s.charInfo.birthdate === "string") charInfoBirthdateLabel.textContent = s.charInfo.birthdate;
            if (charInfoNationalityLabel && typeof s.charInfo.nationality === "string") charInfoNationalityLabel.textContent = s.charInfo.nationality;
            if (charInfoCashLabel && typeof s.charInfo.cash === "string") charInfoCashLabel.textContent = s.charInfo.cash;
            if (typeof s.charInfo.play === "string") charInfoPlayLabel = s.charInfo.play;
            if (typeof s.charInfo.create === "string") charInfoCreateLabel = s.charInfo.create;
            if (charInfoGenderMale && typeof s.charInfo.genderMale === "string") charInfoGenderMale.textContent = s.charInfo.genderMale;
            if (charInfoGenderFemale && typeof s.charInfo.genderFemale === "string") charInfoGenderFemale.textContent = s.charInfo.genderFemale;
            if (charInfoDelete && typeof s.charInfo.delete === "string") charInfoDelete.textContent = s.charInfo.delete;
        }
        if (typeof s.cancel === "string") {
            dialogCancel.textContent = s.cancel;
            alertCancel.textContent = s.cancel;
        }
        if (typeof s.confirm === "string") {
            dialogSubmit.textContent = s.confirm;
            alertConfirm.textContent = s.confirm;
        }
    }

    function post(cb, data) {
        fetch(`https://${resourceName}/${cb}`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(data || {})
        }).catch((err) => {
            console.warn(`[rsg-character] post("${cb}") failed:`, err);
        });
    }

    function show(el) { el.classList.remove("hidden"); }
    function hide(el) { el.classList.add("hidden"); }

    function clamp(v, min, max) { return Math.min(max, Math.max(min, v)); }

    function renderMenu(payload) {
        currentElements = payload.elements || [];
        menuTitle.textContent = payload.title || "";
        menuSubtitle.textContent = payload.subtitle || "";
        menuList.innerHTML = "";

        if (cameraMoveBar) {
            if (payload.hideCameraBar) {
                hide(cameraMoveBar);
            } else {
                show(cameraMoveBar);
            }
        }

        let groupBox = null, groupKey = null;
        currentElements.forEach((el, index) => {
            if (el.type === "section") {
                const h = document.createElement("div");
                h.className = "menu-section";
                h.textContent = stripTags(el.label);
                groupBox = null; groupKey = null;
                menuList.appendChild(h);
                return;
            }
            const row = el.type === "slider" ? buildSliderRow(el, index) : buildListRow(el, index);
            if (el.group != null) {
                if (!groupBox || groupKey !== el.group) {
                    groupBox = document.createElement("div");
                    groupBox.className = "row-group";
                    groupKey = el.group;
                    menuList.appendChild(groupBox);
                }
                groupBox.appendChild(row);
            } else {
                groupBox = null; groupKey = null;
                menuList.appendChild(row);
            }
        });

        show(app);
        show(menuPanel);
    }

    function stripTags(html) {
        if (!html) return "";
        const tmp = document.createElement("div");
        tmp.innerHTML = html;
        return tmp.textContent || tmp.innerText || "";
    }

    function buildListRow(el, index) {
        const row = document.createElement("div");
        row.className = "row" + (el.cta ? " row-cta" : "") + (el.highlight ? " row-highlight" : "") + (el.danger ? " row-danger" : "") + (el.disabled ? " disabled" : "");

        const icon = document.createElement("div");
        icon.className = "row-icon";
        if (el.icon) icon.style.backgroundImage = `url("${encodeURI(el.icon).replace(/"/g, '%22')}")`;
        row.appendChild(icon);

        const body = document.createElement("div");
        body.className = "row-body";

        const title = document.createElement("div");
        title.className = "row-title";
        title.innerHTML = el.label || "";
        body.appendChild(title);

        const desc = stripTags(el.desc);
        if (desc) {
            const descEl = document.createElement("div");
            descEl.className = "row-desc";
            descEl.textContent = desc;
            body.appendChild(descEl);
        }
        row.appendChild(body);

        if (el.badge) {
            const badge = document.createElement("div");
            badge.className = "row-badge";
            badge.textContent = el.badge;
            row.appendChild(badge);
        }

        if (el.action) {
            const actionBtn = document.createElement("div");
            actionBtn.className = "row-action-btn";
            actionBtn.title = el.action.title || "";
            actionBtn.innerHTML = rowActionIcon(el.action.icon);
            actionBtn.addEventListener("click", (e) => {
                e.stopPropagation();
                post("rowAction", { index });
            });
            row.appendChild(actionBtn);
        }

        if (!el.disabled) {
            row.addEventListener("click", () => post("select", { index }));
        }

        return row;
    }

    function rowActionIcon(icon) {
        if (icon === "trash") {
            return '<svg viewBox="0 0 24 24"><path d="M9 3a1 1 0 0 0-1 1v1H4v2h1.1l1.2 12.1A2 2 0 0 0 8.29 21h7.42a2 2 0 0 0 1.99-1.9L18.9 7H20V5h-4V4a1 1 0 0 0-1-1H9zm1 2h4v0h-4v0zM7.11 7h9.78l-1.15 11.9H8.26L7.11 7zM10 9v8h1.5V9H10zm2.5 0v8H14V9h-1.5z"/></svg>';
        }
        return "";
    }

    function buildSliderRow(el, index) {
        const row = document.createElement("div");
        row.className = "row slider-row";

        const top = document.createElement("div");
        top.className = "slider-top";
        const label = document.createElement("span");
        label.innerHTML = el.label || "";
        const value = document.createElement("span");
        value.className = "slider-value";
        const fmt = (v) => el.showCount !== false ? `${v}/${typeof el.max === "number" ? el.max : 0}` : v;
        value.textContent = fmt(el.value);
        top.appendChild(label);
        top.appendChild(value);
        row.appendChild(top);

        const controls = document.createElement("div");
        controls.className = "slider-controls";

        const min = typeof el.min === "number" ? el.min : 0;
        const max = typeof el.max === "number" ? el.max : 100;
        const hop = el.hop && el.hop > 0 ? el.hop : 1;

        const left = document.createElement("div");
        left.className = "slider-arrow";
        left.textContent = "‹";

        const track = document.createElement("div");
        track.className = "slider-track";
        const fill = document.createElement("div");
        fill.className = "slider-fill";
        track.appendChild(fill);

        const right = document.createElement("div");
        right.className = "slider-arrow";
        right.textContent = "›";

        function pct(v) {
            if (max === min) return 0;
            return clamp(((v - min) / (max - min)) * 100, 0, 100);
        }

        function setValue(v) {
            v = clamp(v, min, max);
            el.value = v;
            value.textContent = fmt(v);
            fill.style.width = pct(v) + "%";
            post("sliderChange", { index, value: v });
        }

        fill.style.width = pct(el.value) + "%";

        left.addEventListener("click", () => setValue((el.value || 0) - hop));
        right.addEventListener("click", () => setValue((el.value || 0) + hop));
        track.addEventListener("click", (ev) => {
            const rect = track.getBoundingClientRect();
            const ratio = clamp((ev.clientX - rect.left) / rect.width, 0, 1);
            setValue(Math.round(min + ratio * (max - min)));
        });

        controls.appendChild(left);
        controls.appendChild(track);
        controls.appendChild(right);
        row.appendChild(controls);

        return row;
    }

    let selectedGender = "male";

    function setSelectedGender(gender) {
        selectedGender = gender === "female" ? "female" : "male";
        charInfoGenderMale.classList.toggle("selected", selectedGender === "male");
        charInfoGenderFemale.classList.toggle("selected", selectedGender === "female");
    }

    function showCharInfo(msg) {
        charInfoName.textContent = msg.name || "";
        charInfoPanel.classList.toggle("empty-slot", !!msg.empty);

        if (msg.empty) {
            hide(charInfoRows);
            show(charInfoDescEl);
            charInfoDescEl.textContent = msg.desc || "";
            hide(charInfoDelete);
            charInfoPlay.textContent = charInfoCreateLabel;
            show(charInfoGenderRow);
            setSelectedGender("male");
            post("charInfoGenderChange", { gender: "male" });
        } else {
            show(charInfoRows);
            hide(charInfoDescEl);
            charInfoJob.textContent = msg.job || "";
            charInfoBirthdate.textContent = msg.birthdate || "";
            charInfoNationality.textContent = msg.nationality || "";
            charInfoCash.textContent = msg.cash || "";
            show(charInfoDelete);
            charInfoPlay.textContent = charInfoPlayLabel;
            hide(charInfoGenderRow);
        }

        show(app);
        show(charInfoPanel);
    }

    function hideCharInfo() {
        hide(charInfoPanel);
        if (menuPanel.classList.contains("hidden")
            && dialogModal.classList.contains("hidden")
            && alertModal.classList.contains("hidden")) {
            hide(app);
        }
    }

    charInfoGenderMale.addEventListener("click", () => {
        setSelectedGender("male");
        post("charInfoGenderChange", { gender: "male" });
    });
    charInfoGenderFemale.addEventListener("click", () => {
        setSelectedGender("female");
        post("charInfoGenderChange", { gender: "female" });
    });

    charInfoPlay.addEventListener("click", () => post("charInfoPlay", {}));
    charInfoDelete.addEventListener("click", () => post("charInfoDelete", {}));

    function closeAll() {
        hide(menuPanel);
        hide(dialogModal);
        hide(alertModal);
        hide(charInfoPanel);
        hide(app);
    }

    let dialogFieldDefs = [];

    function openDialog(msg) {
        dialogFieldDefs = msg.fields || [];
        dialogTitle.textContent = msg.header || "";
        dialogFields.innerHTML = "";

        dialogFieldDefs.forEach((f, i) => {
            const wrap = document.createElement("div");
            wrap.className = "modal-field";
            const label = document.createElement("label");
            label.textContent = f.label || "";
            wrap.appendChild(label);

            if (f.type === "select") {
                const select = document.createElement("select");
                select.dataset.index = i;
                if (!f.default) {
                    const placeholderOpt = document.createElement("option");
                    placeholderOpt.value = "";
                    placeholderOpt.textContent = f.placeholder || "";
                    placeholderOpt.disabled = true;
                    placeholderOpt.selected = true;
                    select.appendChild(placeholderOpt);
                }
                (f.options || []).forEach((opt) => {
                    const optionEl = document.createElement("option");
                    const value = typeof opt === "string" ? opt : opt.value;
                    const optLabel = typeof opt === "string" ? opt : (opt.label || opt.value);
                    optionEl.value = value;
                    optionEl.textContent = optLabel;
                    if (f.default && value === f.default) optionEl.selected = true;
                    select.appendChild(optionEl);
                });
                wrap.appendChild(select);
            } else {
                const input = document.createElement("input");
                input.type = f.type === "date" ? "date" : "text";
                input.placeholder = f.placeholder || "";
                if (f.default) input.value = f.default;
                if (f.type === "date") {
                    if (f.min) input.min = f.min;
                    if (f.max) input.max = f.max;
                }
                input.dataset.index = i;
                wrap.appendChild(input);
            }

            dialogFields.appendChild(wrap);
        });

        show(app);
        show(dialogModal);
        const firstInput = dialogFields.querySelector("input, select");
        if (firstInput) firstInput.focus();
    }

    function hideOverlayOrApp(overlayEl) {
        hide(overlayEl);
        if (menuPanel.classList.contains("hidden") && charInfoPanel.classList.contains("hidden")) {
            hide(app);
        }
    }

    dialogSubmit.addEventListener("click", () => {
        const inputs = Array.from(dialogFields.querySelectorAll("input, select"))
            .sort((a, b) => Number(a.dataset.index) - Number(b.dataset.index));
        const values = inputs.map((inp) => inp.value);
        const missing = dialogFieldDefs.some((f, i) => f.required && !values[i]);
        if (missing) return;
        hideOverlayOrApp(dialogModal);
        post("dialogSubmit", { values });
    });

    dialogCancel.addEventListener("click", () => {
        hideOverlayOrApp(dialogModal);
        post("dialogCancel", {});
    });

    function openAlert(msg) {
        alertTitle.textContent = msg.header || "";
        alertCancel.style.display = msg.cancel === false ? "none" : "inline-block";
        show(app);
        show(alertModal);
    }

    alertConfirm.addEventListener("click", () => {
        hideOverlayOrApp(alertModal);
        post("alertConfirm", {});
    });

    alertCancel.addEventListener("click", () => {
        hideOverlayOrApp(alertModal);
        post("alertCancel", {});
    });

    function openSpawnSelect(msg) {
        spawnSelectTitle.textContent = msg.title || "";
        spawnSelectSubtitle.textContent = msg.subtitle || "";
        spawnSelectCards.innerHTML = "";

        (msg.elements || []).forEach((el) => {
            const card = document.createElement("div");
            card.className = "spawn-card";
            card.tabIndex = 0;

            const img = document.createElement("div");
            img.className = "spawn-card-img";
            if (el.image) img.style.backgroundImage = `url("${encodeURI(el.image).replace(/"/g, '%22')}")`;
            card.appendChild(img);

            const label = document.createElement("div");
            label.className = "spawn-card-label";
            label.textContent = el.label || "";
            card.appendChild(label);

            const desc = stripTags(el.desc);
            if (desc) {
                const descEl = document.createElement("div");
                descEl.className = "spawn-card-desc";
                descEl.textContent = desc;
                card.appendChild(descEl);
            }

            const select = () => post("spawnSelect", { value: el.value });
            card.addEventListener("click", select);
            card.addEventListener("keydown", (ev) => {
                if (ev.key === "Enter" || ev.key === " ") {
                    ev.preventDefault();
                    select();
                }
            });

            spawnSelectCards.appendChild(card);
        });

        show(spawnSelectPanel);
    }

    function closeSpawnSelect() {
        hide(spawnSelectPanel);
    }

    function showLoadingScreen(msg) {
        loadingText.textContent = (msg && msg.text) || "";
        show(loadingScreen);
    }

    function hideLoadingScreen() {
        hide(loadingScreen);
    }

    function bindCameraMoveButton(btn, direction) {
        if (!btn) return;

        let active = false;

        function start(ev) {
            if (ev) ev.preventDefault();
            if (active) return;
            active = true;
            btn.classList.add("pressed");
            post("cameraMoveStart", { direction });
        }

        function stop() {
            if (!active) return;
            active = false;
            btn.classList.remove("pressed");
            post("cameraMoveStop", {});
        }

        btn.addEventListener("mousedown", start);
        btn.addEventListener("mouseup", stop);
        btn.addEventListener("mouseleave", stop);
        btn.addEventListener("touchstart", start, { passive: false });
        btn.addEventListener("touchend", stop);
        btn.addEventListener("touchcancel", stop);
    }

    bindCameraMoveButton(camUpBtn, "up");
    bindCameraMoveButton(camDownBtn, "down");
    bindCameraMoveButton(camZoomInBtn, "zoomin");
    bindCameraMoveButton(camZoomOutBtn, "zoomout");
    bindCameraMoveButton(camRotateLeftBtn, "rotateleft");
    bindCameraMoveButton(camRotateRightBtn, "rotateright");

    if (camResetBtn) {
        camResetBtn.addEventListener("click", (ev) => {
            ev.preventDefault();
            post("cameraReset", {});
        });
    }

    window.addEventListener("mouseup", () => post("cameraMoveStop", {}));
    window.addEventListener("blur", () => post("cameraMoveStop", {}));

    btnBack.addEventListener("click", () => post("back", {}));

    document.addEventListener("keydown", (ev) => {
        if (ev.key === "Escape") {
            if (!dialogModal.classList.contains("hidden")) {
                hideOverlayOrApp(dialogModal); post("dialogCancel", {});
            } else if (!alertModal.classList.contains("hidden")) {
                hideOverlayOrApp(alertModal); post("alertCancel", {});
            }
        }
    });

    window.addEventListener("message", (event) => {
        const msg = event.data;
        if (!msg || !msg.action) return;

        switch (msg.action) {
            case "openMenu": renderMenu(msg); break;
            case "closeAll": closeAll(); break;
            case "showCharInfo": showCharInfo(msg); break;
            case "hideCharInfo": hideCharInfo(); break;
            case "dialog": openDialog(msg); break;
            case "alert": openAlert(msg); break;
            case "setLocale": applyLocale(msg); break;
            case "showLoadingScreen": showLoadingScreen(msg); break;
            case "hideLoadingScreen": hideLoadingScreen(); break;
            case "openSpawnSelect": openSpawnSelect(msg); break;
            case "closeSpawnSelect": closeSpawnSelect(); break;
        }
    });

    post("uiReady", {});
})();
