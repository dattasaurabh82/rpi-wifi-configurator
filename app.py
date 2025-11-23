from button import Button
from led import LED
from wifi_config.network_manager import NetworkManager
from wifi_config.web_server import run_server, stop_server, server_running, switch_to_ap_mode, switch_to_normal_mode, reset_wifi_state
import threading
import time
from logger import logger
import configparser
import os
import sys


# ------------------------------------------- #
# ************* Load Configuration ********** #
# ------------------------------------------- #

# Load configuration from config.ini
config = configparser.ConfigParser()
config_path = os.path.join(os.path.dirname(__file__), 'config.ini')

# Read config if exists, otherwise use defaults
if os.path.exists(config_path):
    config.read(config_path)
    AP_SELF_IP = config.get('access_point', 'ap_ip', fallback='10.10.1.1')
    AP_SSID = config.get('access_point', 'ap_ssid', fallback='RPI_NET_SETUP')
    WIFI_RESET_PIN = config.getint('hardware', 'button_gpio_pin', fallback=23)
    LED_PIN = config.getint('hardware', 'led_gpio_pin', fallback=24)
    PORT = config.getint('server', 'port', fallback=4000)
    logger.info(f"[app.py][Config] Loaded from config.ini: SSID={AP_SSID}, Button={WIFI_RESET_PIN}, LED={LED_PIN}, PORT={PORT}")
else:
    # Fallback to defaults if config.ini doesn't exist
    AP_SELF_IP = "10.10.1.1"
    AP_SSID = "RPI_NET_SETUP"
    WIFI_RESET_PIN = 23
    LED_PIN = 24
    PORT = 4000
    logger.warning("[app.py][Config] config.ini not found, using defaults")


# ------------------------------------------- #
# ************* Global Variables ************ #
# ------------------------------------------- #

# * Note: From webserver and DNSServer 
server_thread = None
server_running = False


# ------------------------------------------- #
# * Call back functions for button presses * #
# ------------------------------------------- #

def on_short_press():
    logger.info("[app.py][Event] Short Press detected... Do nothing!")


def on_long_press():
    global server_thread, server_running
    logger.info("")  # For a new line
    logger.info("[app.py][Event] Long Press detected!")

    logger.info("[app.py][Action] Setting up Access Point ...")
    
    # Set LED to fast blink for AP mode
    status_led.set_state(LED.FAST_BLINK)
    
    NetworkManager.setup_ap()
    reset_wifi_state()  # Reset the WiFi state
    switch_to_ap_mode()

    logger.info(f"[app.py][Result] AP mode activated. Connect to the Wi-Fi and navigate to http://{AP_SELF_IP}:{PORT}")


# ------------------------------------------ #
# ******** Create a Button instance ******** #
# ------------------------------------------ #

button = Button(pin=WIFI_RESET_PIN, debounce_time=0.02, long_press_time=4)
# Note: Default Values in the class 
# GPIO pin is 23 
# Debounce time is 10 ms (0.01)
# Long press threshold time period is 5 sec

button.on_short_press = on_short_press
button.on_long_press = on_long_press

# ------------------------------------------ #
# -------- Process status signal LED ------- #
# ------------------------------------------ #
status_led = LED(pin=LED_PIN, max_brightness=0.3)  # 30% brightness
from wifi_config.web_server import init_app
init_app(status_led)

# ------------------------------------------ # 

def main():
    global server_thread, server_running
    
    # Start the web server in daemon thread (exits when main thread exits)
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    server_running = True
    
    # Initialize last known state
    last_known_ip = NetworkManager.get_current_ip()
    
    # Determine initial mode based on connection state
    if NetworkManager.is_in_ap_mode():
        last_known_mode = "ap"
        status_led.set_state(LED.FAST_BLINK)
    elif NetworkManager.is_connected_to_wifi():
        last_known_mode = "connected"
        status_led.set_state(LED.OFF)
    else:
        last_known_mode = "disconnected"
        status_led.set_state(LED.SLOW_BLINK)
    
    try:
        while True:
            time.sleep(1)
            current_ip = NetworkManager.get_current_ip()
            
            if NetworkManager.is_in_ap_mode():
                # Case 1: AP mode active
                if last_known_mode != "ap":
                    logger.info("[app.py][Action] Switched to AP mode.")
                    switch_to_ap_mode()
                    status_led.set_state(LED.FAST_BLINK)
                    last_known_mode = "ap"
                    
            elif NetworkManager.is_connected_to_wifi():
                # Case 2: Connected to WiFi
                if last_known_mode != "connected":
                    logger.info("[app.py][Action] Connected to Wi-Fi. Switching to normal mode...")
                    switch_to_normal_mode()
                    status_led.set_state(LED.SOLID)
                    time.sleep(2)
                    status_led.set_state(LED.OFF)
                    last_known_mode = "connected"
                    
            else:
                # Case 3: Not in AP mode and not connected = disconnected/searching
                if last_known_mode != "disconnected":
                    logger.info("[app.py][Action] WiFi disconnected or not found.")
                    status_led.set_state(LED.SLOW_BLINK)
                    last_known_mode = "disconnected"
            
            last_known_ip = current_ip
    except KeyboardInterrupt:
        logger.info("[app.py][Result] Shutting down gracefully...")
        status_led.cleanup()
        sys.exit(0)
                
# ------------------------------------------ #


logger.info("-----------------------")
logger.info("SERIAL MON SYS VIEW | LOG")
logger.info("-----------------------")
logger.info("Artist: Saurabh Datta")
logger.info("Loc: Berlin, Germany")
logger.info("Date: Jan, 2025")
logger.info("-----------------------")


# If wifi connected print IP address. if not type a message below
logger.info(f"[app.py][Status] Current IP: {NetworkManager.get_current_ip()}")
if NetworkManager.get_current_ip() == AP_SELF_IP:
    logger.info(f"[app.py][Status] Connect to wifi access point: {AP_SSID} and go to: http://serialmonitor.local:{PORT} or http://serialmonitor.lan:{PORT} to provide 2.5GHz Wifi credentials")
else:
    logger.info("[app.py][Status] To configure wifi, Long Press the Wifi Reset Button for more than 5 sec")
    


if __name__ == "__main__":
    main()
