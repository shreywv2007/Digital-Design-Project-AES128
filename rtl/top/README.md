# Member 4 — Integration and Testing

## Files
| File | What it is |
|---|---|
| `rtl/top/aes_top.v` | Top-level design: UART (Member 3) → controller → key expansion + encrypt (Member 1) / decrypt (Member 2) → UART reply |
| `rtl/top/de10_lite_top.v` | DE10-Lite board wrapper: 50 MHz clock, KEY0 = reset, LEDs, UART on GPIO[0]/GPIO[1] |
| `constraints/de10_lite_pins.tcl` | Quartus pin assignments (check against the DE10-Lite manual) |
| `constraints/de10_lite.sdc` | 50 MHz timing constraint |
| `tb/tb_aes_cores.v` | Unit tests: key expansion, encrypt, decrypt (FIPS-197 vectors + round trips + reset) |
| `tb/tb_aes_top.v` | Whole-system test over the real UART pins, acting like the host script |
| `sim/run_sim.ps1` | Runs both testbenches with Icarus Verilog |

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
Needs Icarus Verilog (`winget install Icarus.Verilog`). Current result: 17/17 core checks and 9/9 system checks pass.

## Hardware hookup (DE10-Lite)
The DE10-Lite has no built-in USB-serial, so use a **3.3 V** USB-to-TTL adapter:
adapter TX → GPIO[0], adapter RX → GPIO[1], GND → GND.
Then run `host/aes_uart_demo.py` with that adapter's serial port.
