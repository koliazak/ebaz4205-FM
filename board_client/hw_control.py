import logging
import os
import mmap
import struct

BASE_ADDR = 0x43c00000
LENGTH = 0x10000
CTRL_REG = 0x00
STATUS_REG = 0x04
FREQ_100KHZ_REG = 0x08
CONFIG_REG = 0x0C
SCAN_RESULT_REG = 0x10

logger = logging.getLogger(__name__)


class FPGARadioController:
    def __init__(self, base_addr=BASE_ADDR, length=LENGTH, uio_dev="/dev/uio1"):
        self.mem = None
        self.uio_dev = None
        self.fd_irq = None
        self.fd_mem = None

        self.base_addr = base_addr
        self.length = length

        try:
            self.fd_mem = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
            self.mem = mmap.mmap(self.fd_mem, self.length, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE,
                                 offset=self.base_addr)
            logger.info("AXI registers mapped successfully.")
        except Exception as ex:
            logger.error(f"Couldn't open /dev/mem: {ex}")

        if uio_dev:
            self.uio_dev = uio_dev
            try:
                self.fd_irq = os.open(self.uio_dev, os.O_RDWR)
                logger.info(f"UIO Interrupt driver ({self.uio_dev}) opened successfully.")

            except Exception as e:
                logger.error(f"Failed to open UIO device: {e}")
                self.fd_irq = None

    def __del__(self):
        try:
            self.close()
        except Exception:
            pass

    def close(self):
        if self.mem is not None:
            try:
                self.mem.close()
            except Exception as ex:
                logger.warning(f"Failed to close mmap: {ex}")
            finally:
                self.mem = None

        if self.fd_mem is not None:
            try:
                os.close(self.fd_mem)
            except Exception as ex:
                logger.warning(f"Failed to close /dev/mem fd: {ex}")
            finally:
                self.fd_mem = None

        if self.fd_irq is not None:
            try:
                os.close(self.fd_irq)
            except Exception as ex:
                logger.warning(f"Failed to close UIO fd: {ex}")
            finally:
                self.fd_irq = None

    def enable_irq(self):
        if self.fd_irq is None or not self.mem:
            return False

        self.mem.seek(CTRL_REG)
        self.mem.write(struct.pack("<I", (1 << 3)))
        return True

    def clear_done(self):
        if self.fd_irq is None or not self.mem:
            return False

        self.mem.seek(CTRL_REG)
        self.mem.write(struct.pack("<I", (1 << 2)))
        return True

    def wait_irq(self):
        if self.fd_irq is None or not self.mem:
            return False

        try:
            self.enable_irq()
            os.write(self.fd_irq, struct.pack("<I", 1))

            os.read(self.fd_irq, 4)
            self.clear_done()
            return True
        except Exception as ex:
            logger.error(f"UIO Read Error: {ex}")
            return False

    def set_freq(self, freq_mhz: float):
        if self.mem is None:
            return False

        freq_int = int(freq_mhz * 10)

        if freq_int < 875 or freq_int > 1080:
            logger.warning(f"set_freq: received poor data: {freq_mhz}")
            return False

        is_search_active = self.get_search_status()

        if is_search_active:
            self.toggle_search_mode()

        data = struct.pack("<I", freq_int)

        self.mem.seek(FREQ_100KHZ_REG)
        self.mem.write(data)
        self.mem.seek(CTRL_REG)
        self.mem.write(struct.pack("<I", 1))

        return True

    def search_up(self):
        if self.mem is None:
            return False
        is_search_active = self.get_search_status()

        if not is_search_active:
            self.toggle_search_mode()

        self.mem.seek(CONFIG_REG)
        data = self.mem.read(4)
        config_val = struct.unpack("<I", data)[0]
        # STANDBY,SEARCH_UP,SEARCH_EN,MONO,MUTE
        config_val = config_val | (1 << 3)
        data = struct.pack("<I", config_val)
        self.mem.seek(CONFIG_REG)
        self.mem.write(data)

        self.mem.seek(CTRL_REG)
        self.mem.write(struct.pack("<I", 1))
        return True

    def search_down(self):
        if self.mem is None:
            return False
        is_search_active = self.get_search_status()

        if not is_search_active:
            self.toggle_search_mode()

        self.mem.seek(CONFIG_REG)
        data = self.mem.read(4)
        config_val = struct.unpack("<I", data)[0]
        # STANDBY,SEARCH_UP,SEARCH_EN,MONO,MUTE
        config_val = config_val & ~(1 << 3)
        data = struct.pack("<I", config_val)
        self.mem.seek(CONFIG_REG)
        self.mem.write(data)

        self.mem.seek(CTRL_REG)
        self.mem.write(struct.pack("<I", 1))
        return True

    def get_search_status(self):
        if self.mem is None:
            return False
        self.mem.seek(STATUS_REG)
        data = self.mem.read(4)
        status_val = struct.unpack("<I", data)[0]

        # SEARCH_MODE,TUNED,SCANNING,STEREO,STATION_FOUND,DONE,BUSY
        is_search_active = bool((status_val >> 6) & 1)
        return is_search_active

    def toggle_search_mode(self):
        if self.mem is None:
            return False
        self.mem.seek(CONFIG_REG)
        data = self.mem.read(4)
        config_val = struct.unpack("<I", data)[0]
        # STANDBY,SEARCH_UP,SEARCH_EN,MONO,MUTE
        config_val = config_val | (1 << 2)
        data = struct.pack("<I", config_val)
        self.mem.seek(CONFIG_REG)
        self.mem.write(data)
        return True

    def get_freq(self):
        if self.mem is None:
            return 0

        if self.get_search_status():
            self.mem.seek(SCAN_RESULT_REG)
        else:
            self.mem.seek(FREQ_100KHZ_REG)

        data = self.mem.read(4)
        result_val = struct.unpack("<I", data)[0]

        freq_int = result_val & 0x7ff
        freq_mhz = freq_int / 10

        logger.info(f"[HW] Current frequency is {freq_mhz}MHz")

        return freq_mhz