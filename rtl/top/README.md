# Member 4 — Integration and Testing

## Files
| File | What it is |
|---|---|
| `aes_top.v` | Wires everything together: UART (Member 3) → controller → key expansion + encrypt (Member 1) / decrypt (Member 2) → UART reply |
| `aes_controller.v` | Main state machine: IDLE → EXPAND → START → RUN → RESPOND → WAIT_TX |
| `input_registers.v` | Holds command, key, data and the 11 round keys steady during a run |
| `mode_selector.v` | Sends start to the encrypt or decrypt core and picks that core's result |
| `output_registers.v` | Holds the reply status (00 OK / 01 invalid command) and result |
| `status_leds.v` | Busy, error, done and heartbeat LEDs |
| `seven_segment_display.v` | Shows the first 3 result bytes on HEX5..HEX0 |
| `de10_lite_top.v` | DE10-Lite board wrapper: 50 MHz clock, KEY0 reset, LEDs, 7-segment, UART on GPIO[0]/GPIO[1] |

Related: `quartus/` (project), `constraints/de10_lite.sdc` (timing), `tb/` and `sim/run_sim.ps1` (tests), `docs/` (architecture, protocol, pins).

## How the controller works
1. **IDLE** – waits for a full request from the UART parser.
2. **EXPAND** – stores the 11 round keys in registers so they stay steady.
3. **START** – sends a one-clock start pulse to the encrypt or decrypt core.
4. **RUN** – waits for that core's `done` and saves the result.
5. **RESPOND / WAIT_TX** – sends the 19-byte reply and waits for it to finish.

An unknown command gets status `01` with an all-zero result.
Status `00` means success. One request at a time; requests sent while busy are ignored.

## Integration decisions (answers to Member 3's open questions)
- `packet_error` port: **approved**, invalid-command status = **`01`**.
- Recovery after an interrupted request: press **KEY0** (reset), then retry.
- Only **one outstanding request**; anything received while busy is ignored.
- Clock: DE10-Lite **MAX10_CLK1_50 = 50 MHz**, 115200 baud, synchronous reset.

## Running the tests
```
powershell -ExecutionPolicy Bypass -File sim\run_sim.ps1
```
Needs Icarus Verilog (`winget install Icarus.Verilog`). Current result: 5 testbenches, 64/64 checks pass.

## Hardware hookup (DE10-Lite)
See `docs/pin_connections.md`. Short version: **3.3 V** USB-to-TTL adapter, adapter TX → GPIO[0], adapter RX → GPIO[1], GND → GND, then run `host/aes_uart_demo.py` with that adapter's serial port.
