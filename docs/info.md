<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This design interfaces an HC-SR04 ultrasonic distance sensor, measures the distance to an object, and displays
the result in centimetres on a 4-digit multiplexed 7-segment display.

### Measurement principle

The HC-SR04 works by emitting a short ultrasonic burst and measuring the time until the echo returns.
Distance is calculated from the round-trip time of the pulse at the speed of sound.

The internal clock runs at 10 MHz. A clock divider (`clk_10k`) generates a 10 kHz reference used by the
measurement FSM.

### Block structure

| Block | Function |
|-------|----------|
| `TRIGGER_GEN` | Generates the 10 µs trigger pulse to the HC-SR04 |
| `ENABLE_CTL` | Main FSM (6 states): controls trigger, echo capture, counter reset and display refresh |
| `c999` | BCD/hex distance counter, counts up to 999 cm |
| `clk_10k` | Clock divider: 10 MHz → 10 kHz |
| `display_ctrl` | Latches distance value on each measurement cycle; selects BCD or hex display format |
| `display` | 4-digit time-multiplexed 7-segment driver |
| `bcdto7seg` | BCD to 7-segment decoder |
| `on_off` | Debounced toggle FSM for the Start/Stop button |
| `spi_out` | Serialises the 11-bit distance value over SPI (mode 0, 1.25 MHz, 16-bit frame) |

### SPI output

On each completed measurement, the 11-bit distance value is transmitted over SPI as a 16-bit frame
(`{5'b00000, DISTANCIA[10:0]}`), MSB first, SPI mode 0 (CPOL=0, CPHA=0), at 1.25 MHz.
End of frame is detected by the receiver observing SCLK returning to idle-low after 16 cycles (no CS pin).

## How to test

### Required external hardware

- HC-SR04 ultrasonic distance sensor
- 4-digit common-cathode 7-segment display (with current-limiting resistors on segments)
- Optional: SPI-capable microcontroller or logic analyser on `uio[6]` (SCLK) and `uio[7]` (MOSI)

### Pin connections

| Pin | Direction | Connect to |
|-----|-----------|------------|
| `ui[0]` ENABLE | Input | Active-high enable (tie high to run continuously) |
| `ui[1]` ECHO | Input | HC-SR04 ECHO pin |
| `ui[2]` START_STOP | Input | Momentary push button (active-high, debounced internally) |
| `ui[3]` SW_aux | Input | Display mode: 0 = BCD decimal, 1 = hex |
| `uio[0–3]` Digit 0–3 | Output | Common-cathode digit select (active-low) |
| `uio[4]` TRIGGER | Output | HC-SR04 TRIG pin |
| `uio[5]` Echo copy | Output | Echo passthrough (debug / oscilloscope) |
| `uio[6]` SCLK | Output | SPI clock to microcontroller / logic analyser |
| `uio[7]` MOSI | Output | SPI data to microcontroller / logic analyser |
| `uo[0–6]` Seg A–G | Output | 7-segment display segments (active-low) |
| `uo[7]` DP | Output | Decimal point (active-low) |

### Bring-up sequence

1. Apply power and reset (`rst_n` low, then high).
2. Assert `ui[0]` (ENABLE) high.
3. Press `ui[2]` (START_STOP) to begin measurements.
4. Point the HC-SR04 at an object. The display updates with the distance in centimetres.
5. Toggle `ui[3]` (SW_aux) to switch between decimal (BCD) and hexadecimal display.
6. To read distance digitally, connect a SPI receiver to `uio[6]` (SCLK) and `uio[7]` (MOSI).
   Each 16-bit frame carries the distance in centimetres as an unsigned integer (bits [10:0]).
