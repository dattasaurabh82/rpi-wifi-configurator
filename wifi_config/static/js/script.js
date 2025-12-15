const socket = io();

const networkNameInput = document.getElementById('network-name');
const passwordInput = document.getElementById('password');
const togglePasswordBtn = document.getElementById('toggle-password');
const connectBtn = document.getElementById('connect-btn');
const statusDiv = document.getElementById('status');
const scanBtn = document.getElementById('scan-btn');
const scanResults = document.getElementById('scan-results');
const networkList = document.getElementById('network-list');

// Store selected network's security type
let selectedSecurity = '';

togglePasswordBtn.addEventListener('click', () => {
    if (passwordInput.type === 'password') {
        passwordInput.type = 'text';
        togglePasswordBtn.textContent = '🙈';
    } else {
        passwordInput.type = 'password';
        togglePasswordBtn.textContent = '👀';
    }
});

function connectToWifi() {
    const ssid = networkNameInput.value;
    const password = passwordInput.value;
    
    // OLD
    // if (ssid && password) {
    //     socket.emit('connect_wifi', { ssid, password });
    //     statusDiv.textContent = 'Connecting...';
    // } else {
    //     alert('Please enter a network name and password.');
    // }

    // NEW
    if (ssid) {
        // Password is optional (for open networks)
        socket.emit('connect_wifi', { ssid, password });
        statusDiv.textContent = 'Connecting...';
    } else {
        alert('Please enter a network name.');
    }
}

connectBtn.addEventListener('click', connectToWifi);

// Add this new event listener
passwordInput.addEventListener('keyup', (event) => {
    if (event.key === 'Enter') {
        connectToWifi();
    }
});

socket.on('connection_result', (data) => {
    if (data.success) {
        statusDiv.textContent = `Connected successfully. IP: ${data.ip}`;
    } else {
        statusDiv.textContent = `Connection failed: ${data.error}`;
        alert('Connection failed. Please try again.');
    }
});

// Scan button click handler
scanBtn.addEventListener('click', () => {
    scanBtn.textContent = 'Scanning...';
    scanBtn.disabled = true;
    statusDiv.textContent = '';
    socket.emit('scan_wifi');
});

// Handle scan results from server
socket.on('scan_results', (data) => {
    scanBtn.textContent = 'Scan Networks';
    scanBtn.disabled = false;
    
    if (data.success) {
        networkList.innerHTML = '';
        
        if (data.networks.length === 0) {
            statusDiv.textContent = 'No networks found';
            scanResults.classList.add('hidden');
            return;
        }
        
        data.networks.forEach(network => {
            const li = document.createElement('li');
            li.innerHTML = `<span class="ssid">${network.ssid}</span><span class="security">${network.security}</span>`;
            li.dataset.ssid = network.ssid;
            li.dataset.security = network.security;
            li.addEventListener('click', () => {
                networkNameInput.value = network.ssid;
                selectedSecurity = network.security;
                scanResults.classList.add('hidden');
                passwordInput.focus();
            });
            networkList.appendChild(li);
        });
        
        scanResults.classList.remove('hidden');
    } else {
        statusDiv.textContent = `Scan failed: ${data.error}`;
        scanResults.classList.add('hidden');
    }
});

socket.on('connect', () => {
    console.log('Connected to server');
});