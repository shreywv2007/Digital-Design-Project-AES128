# Pin connections (Terasic DE10-Lite)

Device: Intel MAX 10 **10M50DAF484C7G**. All assignments live in `quartus/aes128.qsf`.
**Check every pin against the DE10-Lite User Manual before programming.**

## Clock and reset
| Signal | FPGA pin | Board part | Notes |
|---|---|---|---|
| `MAX10_CLK1_50` | PIN_P11 | 50 MHz oscillator | System clock |
| `KEY[0]` | PIN_B8 | Push button KEY0 | Reset (active low, pressed = reset) |
| `KEY[1]` | PIN_A7 | Push button KEY1 | Not used |

## UART (via 3.3 V USB-to-TTL adapter on the GPIO header)
The DE10-Lite has **no USB-serial chip**, so an external adapter is required. **Use 3.3 V only, never 5 V.**

| Signal | FPGA pin | GPIO header | Connect to adapter |
|---|---|---|---|
| `UART_RXD` (FPGA receives) | PIN_V10 | GPIO[0], header pin 1 | Adapter **TX** |
| `UART_TXD` (FPGA sends) | PIN_W10 | GPIO[1], header pin 2 | Adapter **RX** |
| Ground | – | GND, header pin 12 or 30 | Adapter **GND** |

`UART_RXD` has the weak pull-up enabled so the line idles high if the adapter is unplugged.

## LEDs (active high)
| LED | FPGA pin | Meaning |
|---|---|---|
| LEDR0 | PIN_A8 | Busy: request in progress |
| LEDR1 | PIN_A9 | Last request had an invalid command |
| LEDR2 | PIN_A10 | Last request finished successfully |
| LEDR3–LEDR8 | B10, D13, C13, E14, D14, A11 | Off |
| LEDR9 | PIN_B11 | Heartbeat blink (design is running) |

## 7-segment displays (active low, `{DP,g,f,e,d,c,b,a}`)
Show the first 3 bytes of the last result; blank until a result is ready. After the C.1 encrypt demo they read **`69C4E0`**.

| Display | Digit | a | b | c | d | e | f | g | DP |
|---|---|---|---|---|---|---|---|---|---|
| HEX5 | result[127:124] | J20 | K20 | L18 | N18 | M20 | N19 | N20 | L19 |
| HEX4 | result[123:120] | F18 | E20 | E19 | J18 | H19 | F19 | F20 | F17 |
| HEX3 | result[119:116] | F21 | E22 | E21 | C19 | C20 | D19 | E17 | D22 |
| HEX2 | result[115:112] | B20 | A20 | B19 | A21 | B21 | C22 | B22 | A22 |
| HEX1 | result[111:108] | C18 | D18 | E18 | B16 | A17 | A18 | B17 | A19 |
| HEX0 | result[107:104] | C14 | E15 | C15 | C16 | E16 | D17 | C17 | D15 |

All I/O uses the 3.3-V LVTTL standard (push buttons: 3.3 V Schmitt trigger).
