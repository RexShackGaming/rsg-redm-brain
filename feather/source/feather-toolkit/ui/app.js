(() => {
    const root = document.getElementById('progress');
    const message = document.getElementById('progress-message');
    const seconds = document.getElementById('progress-seconds');
    let activeId = null;
    let timer = null;
    let ticker = null;

    function reset() {
        if (timer) clearTimeout(timer);
        if (ticker) clearInterval(ticker);
        timer = null;
        ticker = null;
        activeId = null;
        root.className = 'progress hidden';
        root.style.removeProperty('--duration');
    }

    function complete(id) {
        if (!id || id !== activeId) return;
        reset();
        fetch(`https://${GetParentResourceName()}/toolkit_progress_complete`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id })
        }).catch(() => {});
    }

    function open(data) {
        if (activeId || typeof data.id !== 'string') return;
        activeId = data.id;
        message.textContent = typeof data.message === 'string' ? data.message : '';
        root.className = `progress theme-${data.theme}`;
        root.style.setProperty('--color', data.color);
        root.style.setProperty('--width', `${data.widthPercent}vw`);
        root.style.setProperty('--duration', `${data.durationMs}ms`);
        const deadline = Date.now() + data.durationMs;
        const updateSeconds = () => {
            seconds.textContent = `${Math.max(0, Math.ceil((deadline - Date.now()) / 1000))}s`;
        };
        updateSeconds();
        ticker = setInterval(updateSeconds, 200);
        timer = setTimeout(() => complete(data.id), data.durationMs);
    }

    window.addEventListener('message', async ({ data }) => {
        if (!data || typeof data.type !== 'string') return;
        if (data.type === 'copy' && typeof data.text === 'string') {
            try {
                await navigator.clipboard.writeText(data.text);
            } catch (_) {
                const element = document.createElement('textarea');
                element.value = data.text;
                document.body.appendChild(element);
                element.select();
                document.execCommand('copy');
                element.remove();
            }
            return;
        }
        if (data.type === 'progress.open') open(data);
        if (data.type === 'progress.reset' ||
            (data.type === 'progress.close' && data.id === activeId)) reset();
    });
})();
