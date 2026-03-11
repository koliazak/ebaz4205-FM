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

| Offset | Name        | Mode | Description                 |
| ------ | ----------- | ---- | --------------------------- |
| 0x00   | CTRL        | WO   | Command register            |
| 0x04   | STATUS      | RO   | Module status               |
| 0x08   | FREQ_KHZ    | RW   | Desired FM frequency in kHz |
| 0x0C   | CONFIG      | RW   | Tuner configuration         |
| 0x10   | SCAN_RESULT | RO   | Found station information   |

### CTRL Register (0x00)
Control register used to start operations. 

| Bit | Name     | Description             |
| --- | -------- | ----------------------- |
| 2   | CLR_DONE | Clear DONE flag         |
| 1   | ABORT    | Abort current operation |
| 0   | START    | Start operation         |

### STATUS Register (0x04)
Indicates the current state of the controller.

| Bit | Name          | Description                               |
| --- | ------------- | ----------------------------------------- |
| 5   | TUNED         | 1 if tuner is locked to requested station |
| 4   | SCANNING      | 1 if scan is active                       |
| 3   | STEREO        | 1 if station is stereo                    |
| 2   | STATION_FOUND | 1 if scan found valid station             |
| 1   | DONE          | 1 if operation completed successfully     |
| 0   | BUSY          | 1 if operation is in progress             |

### FREQ_KHZ Register (0x08)
Specifies the desired FM frequency.

Example - `101700 = 101.7 MHz`   

### CONFIG Register (0x0C)
Configuration parameters

| Bit | Name      | Description                         |
| --- | --------- | ----------------------------------- |
| 4   | STANDBY   | 1 - standby mode                    |
| 3   | SEARCH_UP | 1 - search up; 0 - search down      |
| 2   | SEARCH_EN | 1 - enable automatic station search |
| 1   | MONO      | 1 - mono output, 0 - stereo         |
| 0   | MUTE      | 1 - audio muted                     |


### SCAN_RESULT Register (0x10)
Contains result of the last sucessful scan operation 

| Bit  | Name     | Description                       |
| ---- | -------- | --------------------------------- |
| 17   | STEREO   | Stereo indicator                  |
| 16:0 | FREQ_KHZ | Detected station frequency in kHz |

## Operation Sequence

### Tune to a specific frequency
1. Write desired frequency to `FREQ_KHZ`
2. Configure parameters in `CONFIG`
3. Set `START` bit in `CTRL` register to 1
4.  Check for `STATUS`. When `BUSY` bit is 0, chek:
	- `STATUS.DONE`
	- `STATUS.TUNED`


### Auto band scan
1. Set `SEARCH_EN` bit in `CONFIG` register to 1
2. Set up `SEARCH_UP` bit in `CONFIG`
3. Set `START` bit in `CTRL` register to 1
4. The controller starts scanning
5. When `STATUS.BUSY` is 0, check `SCAN_RESULT`

