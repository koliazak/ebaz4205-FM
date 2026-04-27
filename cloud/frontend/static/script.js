// AUTH
const API_BASE = window.location.origin;
let ws = null;

function switchView(viewId) {
    document.querySelectorAll('.view').forEach(el => el.style.display = 'none');
    document.getElementById(viewId).style.display = 'block';
}

window.onload = () => {
    const token = localStorage.getItem("access_token");
    if (token) {
        switchView("player-view");
        connectWebSocket(token);
    } else {
        switchView("login-view");
    }
    renderStations();
};

async function handleLogin() {
    const user = document.getElementById("login-user").value;
    const pass = document.getElementById("login-pass").value;

    try {
        const response = await fetch(`${API_BASE}/api/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username: user, password: pass })
        });

        if (response.ok) {
            const data = await response.json();
            localStorage.setItem("access_token", data.access_token);
            localStorage.setItem("user_role", data.role || "registered");
            switchView("player-view");
            connectWebSocket(data.access_token);
        } else {
            showNotification("Error: Invalid login or password", true);
        }
    } catch (e) { console.error("Network error", e); }
}

async function handleRegister() {
    const user = document.getElementById("reg-user").value;
    const pass = document.getElementById("reg-pass").value;

    const response = await fetch(`${API_BASE}/api/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: user, password: pass })
    });

    if (response.ok) {
        showNotification("Registration is successful! Log in.", false);
        switchView("login-view");
    } else {
        const error = await response.json();
        showNotification("Error: " + error.detail, true);
    }
}

async function handleGuest() {
    const response = await fetch(`${API_BASE}/api/auth/guest`, { method: 'POST' });
    if (response.ok) {
        const data = await response.json();
        localStorage.setItem("access_token", data.access_token);
        localStorage.setItem("user_role", "guest");
        switchView("player-view");
        connectWebSocket(data.access_token);
    }
}

function handleLogout() {
    localStorage.removeItem("access_token");
    localStorage.removeItem("user_role");
    if (ws) ws.close();


    if(isPlaying) document.getElementById('start-stop-btn').click();

    switchView("login-view");
}

function connectWebSocket(token) {
    const wsProtocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const wsUrl = `${wsProtocol}//${window.location.host}/client/ws?token=${token}`;

    ws = new WebSocket(wsUrl);

    ws.onerror = function (event) {
        showNotification("Error: couldn't connect to webserver. Log in again.");
        handleLogout();

    }
    ws.binaryType = "arraybuffer";

    ws.onopen = () => console.log("WebSocket connected");

    ws.onmessage = (event) => {
        if (event.data instanceof ArrayBuffer) {
            if (isPlaying && window.audioCtx) {
                const view = new Uint8Array(event.data);
            	const frames = view.length / 2;
            	const buffer = audioCtx.createBuffer(2, frames, 8000);
                const left = buffer.getChannelData(0);
                const right = buffer.getChannelData(1);

                for (let i = 0; i < frames; i++) {
                    left[i] = alawToFloat(view[i * 2 + 0]);
                    right[i] = alawToFloat(view[i * 2 + 1]);
                }

                const source = window.audioCtx.createBufferSource();
                source.buffer = buffer;
                source.connect(window.audioGainNode);

                if (nextTime < window.audioCtx.currentTime) {
                    nextTime = window.audioCtx.currentTime + 0.1;
                }
                source.start(nextTime);
                nextTime += buffer.duration;
            }
        } else {
            const msg = JSON.parse(event.data);
            if (msg.error) {
                showNotification("Server: " + msg.error, true);
            }
            else if (msg.type === "state_update" && msg.freq) {
                const freqSlider = document.getElementById('freq-slider');
                const freqDisplay = document.getElementById('freq-display');
                freqSlider.value = msg.freq;

                if (isSearching) finishSearch(true);
                freqDisplay.innerText = msg.freq.toFixed(1);
                freqDisplay.style.textShadow = "0 0 15px #00ffcc";
                setTimeout(() => freqDisplay.style.textShadow = "0 0 5px rgba(0, 255, 204, 0.5)", 300);
            }
        }
    };

    ws.onclose = async (event) => {
        if (event.code === 1008) {
            const role = localStorage.getItem("user_role");
            if (role === "guest") {
                console.log("Guest token updates automatically...");
                await handleGuest();
            } else {
                showNotification("Your session is expired. Log in again.", true);
                handleLogout();
            }
        } else if (event.code !== 1000 && localStorage.getItem("access_token")) {
            setTimeout(() => connectWebSocket(localStorage.getItem("access_token")), 3000);
        }
    };
}

function sendWsCommand(cmdName, value = null) {
    if (ws && ws.readyState === WebSocket.OPEN) {
        const payload = { target: "zynq_81480f26", cmd: cmdName, value: value };
        ws.send(JSON.stringify(payload));
    }
}


const freqSlider = document.getElementById('freq-slider');
const freqDisplay = document.getElementById('freq-display');

freqSlider.addEventListener('input', (e) => {
    freqDisplay.innerText = parseFloat(e.target.value).toFixed(1);
});
freqSlider.addEventListener('change', (e) => {
    sendWsCommand('set_freq', parseFloat(e.target.value));
});

const knob = document.getElementById('vol-knob');
const volDisplay = document.getElementById('vol-display');
let isDragging = false;
let currentRotation = 0;
const MIN_ANGLE = -135, MAX_ANGLE = 135;

window.localPlayerVolume = 0.5;
knob.style.transform = `rotate(${currentRotation}deg)`;

function getCoords(e) {
    if (e.touches && e.touches.length > 0) {
        return { x: e.touches[0].clientX, y: e.touches[0].clientY };
    }
    return { x: e.clientX, y: e.clientY };
}

function startDrag(e) {
    isDragging = true;
    if (e.type === 'touchstart') e.preventDefault();
}

knob.addEventListener('mousedown', startDrag);
knob.addEventListener('touchstart', startDrag, { passive: false });


window.addEventListener('mouseup', () => {
    if (isDragging) {
        isDragging = false;
    }
});
// window.addEventListener('mousemove', (e) => {
//     if (!isDragging) return;
//     const rect = knob.getBoundingClientRect();
//     const x = e.clientX - (rect.left + rect.width / 2);
//     const y = e.clientY - (rect.top + rect.height / 2);
//     let angle = Math.atan2(y, x) * (180 / Math.PI) + 90;
//     if (angle > 180) angle -= 360;
//     if (angle > MAX_ANGLE) angle = MAX_ANGLE;
//     if (angle < MIN_ANGLE) angle = MIN_ANGLE;
//
//     currentRotation = angle;
//     knob.style.transform = `rotate(${currentRotation}deg)`;
//     const volumePercent = Math.round(((currentRotation - MIN_ANGLE) / (MAX_ANGLE - MIN_ANGLE)) * 100);
//     volDisplay.innerText = volumePercent;
//     window.localPlayerVolume = volumePercent / 100;
//
//     if (window.audioGainNode) {
//         window.audioGainNode.gain.setTargetAtTime(window.localPlayerVolume, window.audioCtx.currentTime, 0.05);
//     }
//
// });

function onDrag(e) {
    if (!isDragging) return;

    const coords = getCoords(e)
    const rect = knob.getBoundingClientRect();
    const x = coords.x - (rect.left + rect.width / 2);
    const y = coords.y - (rect.top + rect.height / 2);

    let angle = Math.atan2(y, x) * (180 / Math.PI) + 90;
    if (angle > 180) angle -= 360;
    if (angle > MAX_ANGLE) angle = MAX_ANGLE;
    if (angle < MIN_ANGLE) angle = MIN_ANGLE;

    currentRotation = angle;
    knob.style.transform = `rotate(${currentRotation}deg)`;
    const volumePercent = Math.round(((currentRotation - MIN_ANGLE) / (MAX_ANGLE - MIN_ANGLE)) * 100);
    volDisplay.innerText = volumePercent;
    window.localPlayerVolume = volumePercent / 100;

    if (window.audioGainNode) {
        window.audioGainNode.gain.setTargetAtTime(window.localPlayerVolume, window.audioCtx.currentTime, 0.05);
    }
}

window.addEventListener('mousemove', onDrag);
window.addEventListener('touchmove', onDrag, { passive: false });


const startStopBtn = document.getElementById('start-stop-btn');
const searchUpBtn = document.getElementById('search-up');
const searchDownBtn = document.getElementById('search-down');

let isPlaying = false;
let searchInterval = null;


window.audioCtx = null;
window.audioGainNode = null;
let nextTime = 0;

startStopBtn.addEventListener('click', async () => {
    isPlaying = !isPlaying;
    if (isPlaying) {

        if (!window.audioCtx) {
            window.audioCtx = new (window.AudioContext || window.webkitAudioContext)({sampleRate: 8000});
            window.audioGainNode = window.audioCtx.createGain();
            window.audioGainNode.connect(window.audioCtx.destination);
        }
        window.audioGainNode.gain.value = window.localPlayerVolume || 0.5;
        // window.audioGainNode.connect(window.audioCtx.destination);

        if (window.audioCtx.state === 'suspended') {
            await window.audioCtx.resume()
        }

        nextTime = window.audioCtx.currentTime + 0.1;


        startStopBtn.innerText = 'STOP';
        startStopBtn.classList.add('playing');
        showNotification("Audio is playing", false);
    } else {

        if (window.audioCtx && window.audioCtx.state === 'running') {
            await window.audioCtx.suspend();
        }

        startStopBtn.innerText = 'START';
        startStopBtn.classList.remove('playing');
        showNotification("Audio is paused", false);
    }
});

let isSearching = false;
let searchTimeout = null;

function startSearch(direction) {
    if (isSearching) return;
    isSearching = true;

    //searchUpBtn.disabled = true;
    //searchDownBtn.disabled = true;

    sendWsCommand(direction === 'up' ? 'scan_up' : 'scan_down');

    // safety timeout
    searchTimeout = setTimeout(() => {
        finishSearch(false);
    }, 4000);
}

function finishSearch(success) {
    isSearching = false;
    searchUpBtn.disabled = false;
    searchDownBtn.disabled = false;
    if (searchTimeout) {
        clearTimeout(searchTimeout);
        searchTimeout = null;
    }

    if (success) {
        freqDisplay.style.textShadow = "0 0 20px #ffffff, 0 0 30px #00ffcc";
        setTimeout(() => freqDisplay.style.textShadow = "0 0 5px rgba(0, 255, 204, 0.5)", 400);
    } else {
        showNotification("Search timeout", true);
    }
}
searchUpBtn.addEventListener('click', () => startSearch('up'));
searchDownBtn.addEventListener('click', () => startSearch('down'));

const saveBtn = document.getElementById('save-btn');
const stationsList = document.getElementById('stations-list');
let savedStations = JSON.parse(localStorage.getItem('radioStations')) || [];

function renderStations() {
    stationsList.innerHTML = '';
    if (savedStations.length === 0) {
        stationsList.innerHTML = '<li style="color:#555; text-align:center; font-size:12px; padding: 10px;">Empty</li>';
        return;
    }
    savedStations.forEach((freq, index) => {
        const li = document.createElement('li');
        li.className = 'station-item';

        const spanFreq = document.createElement('span');
        spanFreq.className = 'station-freq';
        spanFreq.innerText = freq.toFixed(1) + ' MHz';

        li.addEventListener('click', () => {
            freqSlider.value = freq;
            freqDisplay.innerText = freq.toFixed(1);
            sendWsCommand('set_freq', freq);

            freqDisplay.style.textShadow = "0 0 15px #ffffff, 0 0 25px #00ffcc";
            setTimeout(() => freqDisplay.style.textShadow = "0 0 5px rgba(0, 255, 204, 0.5)", 300);
        });

        const deleteBtn = document.createElement('button');
        deleteBtn.className = 'station-delete';
        deleteBtn.innerText = '✖';
        deleteBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            savedStations.splice(index, 1);
            localStorage.setItem('radioStations', JSON.stringify(savedStations));
            renderStations();
        });

        li.appendChild(spanFreq);
        li.appendChild(deleteBtn);
        stationsList.appendChild(li);
    });
}

saveBtn.addEventListener('click', () => {
    const currentFreq = parseFloat(freqSlider.value);
    if (!savedStations.includes(currentFreq)) {
        savedStations.push(currentFreq);
        savedStations.sort((a, b) => a - b);
        localStorage.setItem('radioStations', JSON.stringify(savedStations));
        renderStations();

        const orig = saveBtn.innerText;
        saveBtn.innerText = '✔️'; saveBtn.style.color = '#00ffcc';
        setTimeout(() => { saveBtn.innerText = orig; saveBtn.style.color = ''; }, 1000);
    }
});

function showNotification(message, isError = false) {
    const container = document.getElementById('notification-container');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `toast ${isError ? 'error' : ''}`;
    toast.innerText = message;

    container.appendChild(toast);

    requestAnimationFrame(() => {
        toast.classList.add('show');
    });

    setTimeout(() => {
        toast.classList.remove('show');
        toast.addEventListener('transitionend', () => toast.remove());
    }, 3000);
}

function alawToFloat(a_val) {
    a_val ^= 0x55;
    let t = (a_val & 0x0f) << 4;
    let seg = (a_val & 0x70) >> 4;
    switch (seg) {
        case 0: t += 8; break;
        case 1: t += 0x108; break;
        default: t += 0x108; t <<= (seg - 1);
    }
    let pcm16 = (a_val & 0x80) ? t : -t;
    return pcm16 / 32768.0;
}
