# FM Controller IP

The FM Controller IP provides hardware control of the TEA5767 FM tuner using an FPGA-based I2C master.
The module is accessible from the Zynq Processing System via an AXI4-Lite register interface and supports hardware interrupts for non-blocking operation.

The IP core implements:
- Tuner initialization and frequency tuning
- Automatic radio band scanning
- Hardware interrupt (IRQ) generation upon operation completion
- Status readback and I2C communication

## Register Map

Base Address: Defined by Vivado Address Editor.

| Offset | Name        | Mode | Reset      | Description                          |
| ------ | ----------- | ---- | ---------- | ------------------------------------ |
| 0x00   | CTRL        | RW   | 0x00000000 | Command and interrupt control        |
| 0x04   | STATUS      | RO   | 0x00000000 | Module status flags                  |
| 0x08   | FREQ_100KHZ | RW   | 0x00000000 | Desired FM frequency in 100 kHz steps|
| 0x0C   | CONFIG      | RW   | 0x00000000 | Tuner configuration parameters       |
| 0x10   | SCAN_RESULT | RO   | 0x00000000 | Found station information            |

### CTRL Register (0x00)
Control register used to start operations and manage interrupts.

| Bit | Name     | Mode | Description                                                                 |
| --- | -------- | ---- | --------------------------------------------------------------------------- |
| 3   | IRQ_EN   | RW   | **Interrupt Enable:** 1 - enable hardware IRQ on completion, 0 - disable.   |
| 2   | CLR_DONE | W1C  | **Clear Done:** Write 1 to clear the `DONE` flag and deassert the IRQ line. |
| 1   | RESET    | W1S  | **Reset:** Write 1 to reset (Auto-clears to 0).                             |
| 0   | START    | W1S  | **Start:** Write 1 to start tuning or scanning (Auto-clears to 0).          |

### STATUS Register (0x04)
Indicates the current state of the controller.

| Bit | Name          | Mode | Description                               |
| --- | ------------- | ---- | ----------------------------------------- |
| 5   | TUNED         | RO   | 1 if tuner is locked to requested station |
| 4   | SCANNING      | RO   | 1 if auto-scan is currently active        |
| 3   | STEREO        | RO   | 1 if tuned station is broadcasting stereo |
| 2   | STATION_FOUND | RO   | 1 if auto-scan found a valid station      |
| 1   | DONE          | RO   | 1 if operation completed successfully     |
| 0   | BUSY          | RO   | 1 if I2C/Tuning operation is in progress  |

### FREQ_100KHZ Register (0x08)
Specifies the desired FM frequency in 100 kHz increments.
*Example: For `101.7 MHz`, write `1017` to this register.*
| Bit  | Name        | Mode | Description                                    |
| ---- | ----------- | ---- | ---------------------------------------------- |
| 10:0 | FREQ_100KHZ | RW   | Desired station frequency in 100 kHz           |


### CONFIG Register (0x0C)
Configuration parameters applied during the next `START` assertion.

| Bit | Name      | Mode | Description                                 |
| --- | --------- | ---- | ------------------------------------------- |
| 4   | STANDBY   | RW   | 1 - Standby mode (low power)                |
| 3   | SEARCH_UP | RW   | 1 - Search up the band; 0 - Search down     |
| 2   | SEARCH_EN | RW   | 1 - Enable automatic station search         |
| 1   | MONO      | RW   | 1 - Force mono output; 0 - Stereo mode      |
| 0   | MUTE      | RW   | 1 - Audio output muted                      |

### SCAN_RESULT Register (0x10)
Contains the result of the last successful scan operation.

| Bit   | Name        | Mode | Description                                |
| ----- | ----------- | ---- | ------------------------------------------ |
| 11    | STEREO      | RO   | 1 if the found station is stereo           |
| 10:0  | FREQ_100KHZ | RO   | Detected station frequency in 100 kHz steps|

## Software Operation Sequence (with IRQ)

1. **Setup:** Write the target frequency to `FREQ_100KHZ` or set `SEARCH_EN` in `CONFIG`.
2. **Enable Interrupts:** Write `1` to `CTRL[IRQ_EN]` (Bit 3).
3. **Start:** Write `1` to `CTRL[START]` (Bit 0).
4. **Wait for IRQ:** The Linux Userspace application blocks/sleeps on `/dev/uioX`.
5. **Interrupt Triggered:** The hardware asserts the `irq` line when the operation finishes and `STATUS[DONE]` becomes 1. The application wakes up.
6. **Acknowledge:** The application writes `1` to `CTRL[CLR_DONE]` (Bit 2). This clears the hardware interrupt line, allowing future interrupts.
