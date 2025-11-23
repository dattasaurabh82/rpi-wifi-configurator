import board
import digitalio
import threading
import time
import math

class LED:
    SOLID = "SOLID"
    FAST_BLINK = "FAST"
    SLOW_BREATH = "BREATH"
    OFF = "OFF"

    def __init__(self, pin, max_brightness=0.3):  # 30% brightness by default
        self.pin = getattr(board, f'D{pin}')
        self.led = digitalio.DigitalInOut(self.pin)
        self.led.direction = digitalio.Direction.OUTPUT
        self._state = self.OFF
        self._running = True
        self.max_brightness = max_brightness
        
        self.thread = threading.Thread(target=self._control_led, daemon=True)
        self.thread.start()

    def _pwm_cycle(self, brightness):
        """Execute one PWM cycle with given brightness (0-1)"""
        scaled_brightness = brightness * self.max_brightness
        on_time = scaled_brightness * 0.01  # Max 10ms
        off_time = 0.01 - on_time
        
        self.led.value = True
        time.sleep(on_time)
        self.led.value = False
        time.sleep(off_time)

    def _fast_blink(self):
        """Single blink cycle with controlled brightness"""
        if self.led.value:  # If LED is on, turn it off
            self.led.value = False
            return 0.5  # Off for 500ms
        else:  # If LED is off, turn it on with PWM
            self._pwm_cycle(1.0)  # One PWM cycle at max allowed brightness
            return 0.5  # On for 500ms

    def _slow_breath(self):
        """Creates a smooth breathing effect using sine wave"""
        steps = 100
        for i in range(steps):
            if self._state != self.SLOW_BREATH:
                break
                
            # Generate sine wave from -π/2 to π/2
            x = math.pi * (i / steps) - math.pi/2
            brightness = (math.sin(x) + 1) / 2  # Convert to 0-1 range
            
            self._pwm_cycle(brightness)
        
        return 0.01

    def _solid(self):
        self._pwm_cycle(1.0)  # Full brightness but limited by max_brightness
        return 0.01

    def _off(self):
        self.led.value = False
        return 0.1

    def _control_led(self):
        while self._running:
            if self._state == self.FAST_BLINK:
                sleep_time = self._fast_blink()
            elif self._state == self.SLOW_BREATH:
                sleep_time = self._slow_breath()
            elif self._state == self.SOLID:
                sleep_time = self._solid()
            else:  # OFF
                sleep_time = self._off()
            
            time.sleep(sleep_time)

    def set_state(self, state):
        self._state = state

    def cleanup(self):
        self._running = False
        if self.thread.is_alive():
            self.thread.join()
        self.led.value = False