import logging
from logging.handlers import TimedRotatingFileHandler
import os
from datetime import datetime
# import shutil

class CustomTimedRotatingFileHandler(TimedRotatingFileHandler):
    def __init__(self, filename, when='h', interval=1, backupCount=0, encoding=None, delay=False, utc=False, atTime=None):
        self.root_dir = os.path.dirname(os.path.abspath(__file__))
        self.logs_dir = os.path.join(self.root_dir, "logs")
        os.makedirs(self.logs_dir, exist_ok=True)
        self.main_log_file = os.path.join(self.root_dir, filename)
        super().__init__(self.main_log_file, when, interval, backupCount, encoding, delay, utc, atTime)
        self.initial_backup()

    def initial_backup(self):
            if os.path.exists(self.main_log_file):
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                backup_file = os.path.join(self.logs_dir, f"log_{timestamp}.log")
                os.rename(self.main_log_file, backup_file)  # Rename and move instead of copy

    def doRollover(self):
        if self.stream:
            self.stream.close()
            self.stream = None
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = os.path.join(self.logs_dir, f"log_{timestamp}.log")
        
        if os.path.exists(self.main_log_file):
            os.rename(self.main_log_file, backup_file)
        
        if not self.delay:
            self.stream = self._open()


class Logger:
    def __init__(self, name, log_file='komorebi.log', level=logging.DEBUG):
        self.logger = logging.getLogger(name)
        self.logger.setLevel(level)
        
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        
        # Console handler
        ch = logging.StreamHandler()
        ch.setLevel(level)
        ch.setFormatter(formatter)
        self.logger.addHandler(ch)
        
        # File handler (rotates every 24 hours)
        fh = CustomTimedRotatingFileHandler(log_file, when="D", interval=1, backupCount=0)
        fh.setLevel(level)
        fh.setFormatter(formatter)
        self.logger.addHandler(fh)

        # Disable propagation to avoid duplicate logs
        self.logger.propagate = False

    def debug(self, message):
        self.logger.debug(message)

    def info(self, message):
        self.logger.info(message)

    def warning(self, message):
        self.logger.warning(message)

    def error(self, message):
        self.logger.error(message)

    def critical(self, message):
        self.logger.critical(message)

# Create a global logger instance
logger = Logger('rpi-wifi-configurator')

# Capture Flask and Werkzeug logs
werkzeug_logger = logging.getLogger('werkzeug')
werkzeug_logger.setLevel(logging.ERROR)  # Only log errors from Werkzeug
werkzeug_logger.addHandler(logger.logger.handlers[1])  # Add file handler