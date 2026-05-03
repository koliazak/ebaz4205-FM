# Zynq FM Radio Receiver with Web Streaming

This project implements an internet-accessible FM radio receiver based on the EBAZ4205 (Zynq-7010) platform.

The system allows users to tune FM radio stations remotely through a web interface and listen to the audio stream directly in a web browser.

The design includes:
- FPGA logic for hardware control
- Linux for networking
- A browser user-friendly interface for interaction

## [Video demonstration](https://youtu.be/Bd4GEYbf_hI)

## Features

- Remote FM tuning from browser
- Live audio streaming over the internet
- Automatic FM band scanning
- Playlist of favourite stations
- Local control via physical buttons and display
- FPGA-based radio control
- Real-time audio capture and encoding

## Hardware Components

- EBAZ4205 board (based on Zynq-7010)
- extention board
- TEA5767 FM module
- PCM1808 ADC module

## Architecture

- **Zynq-7010 (PL)**
  - TEA5767 FM control (I2C)
  - I2S audio capture
  - Audio preprocessing
- **Zynq-7010 (PS)**
  - Audio streaming
  - WebSocket client
  - Device control
- **Cloud server**
  - WebSocket relay
  - REST API
  - Device-browser bridge
- **Fronted (Browser)**
  - Audio player
  - Station control UI

## Project structure
```
hw/              FPGA design (Vivado IP core)
sw/              Embedded applications
cloud/           Relay server + frontend
board_client/    Zynq-side client
releases/        Prebuilt boot files
docs/            Schematics and datasheets
```


## Quick Start

### 1. Prepare SD card

- Partition 1 (BOOT): Primary, default offset, size +1024MB, FAT32 (0x0b), bootable flag enabled.
- Partition 2 (rootfs): Primary, default offset, remaining size, Linux (0x83).

Copy boot files (`BOOT.BIN`, `boot.scr`, `image.ub`) to the firsth partiotion
Extract filesystem to the second partition: 
`tar -xzf rootfs.tar.gz -C <PARTIOTION_2>`

### 2. Boot device
1. Insert SD card
2. Connect Ethernet
3. Power on

### 3. Run device client
```
cd /home/petalinux
python zynq_client_minimal.py
```
### 4. Start cloud server
On your PC or remote server:
```
cd cloud
python3 main.py
```

### 5. Open web intterface
