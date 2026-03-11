# FM Controller IP

The FM Controller IP provides hardware control of the TEA5767 FM tuner using an FPGA-based I2C master.
The module is accessible from the Zynq Processing System via an AXI4-Lite register interface.

The IP core implements:
- initialization of the FM tuner
- frequency tuning
- radio band scanning
- status readback
- I2C communication with the tuner


## Register Map

| Offset | Name     | Mode | Description                    |
| ------ | -------- | ---- | ------------------------------ |
| 0x00   | CTRL     | WO   | Control bits: start, stop      |
| 0x04   | STATUS   | RO   | busy, done                     |
| 0x08   | FREQ_KHZ | WO   | Desired FM frequency in kHz    |
| 0x0C   | CONFIG   | RW   | mute, mono/stereo, search mode |

CTRL[1] - start  
CTRL[0] - stop

STATUS[0] - 1 if busy;  0 if ready  

CONFIG[2] - if 1 - mute  
CONFIG[1] - if 1 - mono; if 0 - stereo  
CONFIG[0] - if 1 - search mdoe is on; if 0 - search mode is 0  
