import subprocess
from time import sleep
from logger import logger

class NetworkManager:
    @staticmethod
    def scan_wifi():
        """Scan for available WiFi networks and return list of {ssid, security} dicts"""
        logger.info("[net..._manager.py][Action] Scanning for WiFi networks...")
        
        # Use terse output for easier parsing: SSID:SECURITY
        result = subprocess.run(
            ["nmcli", "-t", "-f", "SSID,SECURITY", "dev", "wifi", "list", "--rescan", "yes"],
            capture_output=True,
            text=True
        )
        
        networks = []
        seen_ssids = set()
        
        for line in result.stdout.strip().split('\n'):
            if not line:
                continue
            
            # Format is SSID:SECURITY (but SSID could contain colons, so split from right)
            parts = line.rsplit(':', 1)
            if len(parts) == 2:
                ssid = parts[0].strip()
                ssid = ssid.replace('\\:', ':')  # Unescape nmcli's escaped colons, iof there's say some spl funky SSID
                security = parts[1].strip() if parts[1].strip() else "Open"
                
                # Skip empty SSIDs and duplicates
                if ssid and ssid not in seen_ssids:
                    seen_ssids.add(ssid)
                    networks.append({"ssid": ssid, "security": security})
        
        # Sort by SSID name (case-insensitive)
        networks.sort(key=lambda x: x["ssid"].lower())
        
        logger.info(f"[net..._manager.py][Result] Found {len(networks)} unique networks")
        return networks

    @staticmethod
    def setup_ap():
        logger.info("[net..._manager.py][Result] Turning predefined AP down, even though it maybe down... [wait 5 sec ...]")
        subprocess.run(["nmcli", "con", "down", "hotspot"], check=False)
        sleep(5)
        logger.info("[net..._manager.py][Result] Turning predefined AP up ... [wait 5 sec ...]")
        try:
            subprocess.run(["nmcli", "con", "up", "hotspot"], check=True)
            sleep(5)
            logger.info("[net..._manager.py][Result] Access Point set up successfully.")
        except subprocess.CalledProcessError as e:
            logger.error(f"[net..._manager.py][Result] Failed to set up Access Point: {e}")
    
    
    @staticmethod
    def connect_to_wifi(ssid, password):
        # First, bring down the hotspot if it's active
        logger.info("[net..._manager.py][Action] Bringing down hotspot before connecting to WiFi...")
        subprocess.run(["nmcli", "con", "down", "hotspot"], check=False)
        sleep(3)
        
        # Check if a connection profile already exists for this SSID
        logger.info(f"[net..._manager.py][Action] Checking for existing connection to {ssid}...")
        check_result = subprocess.run(
            ["nmcli", "-t", "-f", "NAME", "con", "show"],
            capture_output=True,
            text=True
        )
        
        connection_exists = ssid in check_result.stdout
        
        if not connection_exists:
            # Create new connection profile
            # Check if this is an open network (no password) or secured network
            if password:
                # Secured network with WPA-PSK
                logger.info(f"[net..._manager.py][Action] Creating secured connection profile for {ssid}...")
                add_result = subprocess.run([
                    "nmcli", "con", "add",
                    "type", "wifi",
                    "con-name", ssid,
                    "ifname", "wlan0",
                    "ssid", ssid,
                    "wifi-sec.key-mgmt", "wpa-psk",
                    "wifi-sec.psk", password
                ], capture_output=True, text=True)
            else:
                # Open network (no security) - works for truly open AND OWE-TM
                logger.info(f"[net..._manager.py][Action] Creating open connection profile for {ssid}...")
                add_result = subprocess.run([
                    "nmcli", "con", "add",
                    "type", "wifi",
                    "con-name", ssid,
                    "ifname", "wlan0",
                    "ssid", ssid
                ], capture_output=True, text=True)
            
            if add_result.returncode != 0:
                logger.error(f"[net..._manager.py][Error] Failed to create connection: {add_result.stderr}")
                return False, f"Failed to create connection profile: {add_result.stderr}"
            
            sleep(2)
        else:
            logger.info(f"[net..._manager.py][Action] Connection profile exists, will activate it...")
        
        # Now activate the connection
        logger.info(f"[net..._manager.py][Action] Activating connection to {ssid}...")
        result = subprocess.run(
            ["nmcli", "con", "up", ssid],
            capture_output=True,
            text=True
        )
        
        # Wait for connection to stabilize
        sleep(10)
        
        # Check if connection succeeded
        if not NetworkManager.is_connected_to_wifi():
            logger.error(f"[net..._manager.py][Result] Failed to connect to {ssid}")
            logger.error(f"[net..._manager.py][Result] nmcli stdout: {result.stdout}")
            logger.error(f"[net..._manager.py][Result] nmcli stderr: {result.stderr}")
            return False, f"Failed to connect to {ssid}: {result.stderr}"

        # Success
        logger.info(f"[net..._manager.py][Result] Successfully connected to {ssid}")
        return True, f"Connected successfully to {ssid}"
    

    @staticmethod
    def get_current_ip():
        # Get IP address specifically from wlan0 (WiFi interface)
        # Using raw string to avoid escape sequence warning
        cmd = r"ip -4 addr show wlan0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        ip = result.stdout.strip()
        
        # If wlan0 has no IP, fall back to first available IP
        if not ip:
            cmd = "hostname -I | awk '{print $1}'"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            ip = result.stdout.strip()
        
        return ip
    
    @staticmethod
    def is_connected_to_wifi():
        cmd = "nmcli -t -f TYPE,STATE dev | grep '^wifi:connected$'"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.returncode == 0 and not NetworkManager.is_in_ap_mode()

    @staticmethod
    def is_in_ap_mode():
        cmd = "nmcli -t -f NAME con show --active | grep '^hotspot$'"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.returncode == 0
