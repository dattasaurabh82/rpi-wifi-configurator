const socket = io();

const networkNameInput = document.getElementById('network-name');
const passwordInput = document.getElementById('password');
const togglePasswordBtn = document.getElementById('toggle-password');
const connectBtn = document.getElementById('connect-btn');
const statusDiv = document.getElementById('status');

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

socket.on('connect', () => {
    console.log('Connected to server');
});