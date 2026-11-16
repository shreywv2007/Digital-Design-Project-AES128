# AES-128 Encryption / Decryption on FPGA

Digital Design project. The FPGA receives a 128-bit key and a 128-bit block over UART, runs AES-128 encryption or decryption in hardware, and sends the result back to a PC.

```
 PC (host/aes_uart_demo.py)
        │  UART 115200 8-N-1 (3.3 V USB-to-serial adapter)
        ▼
 ┌──────────────────────────── FPGA (DE10-Lite) ────────────────────────────┐
 │  uart_interface ──► aes_top controller ──► aes_key_expansion             │
 │   (Member 3)         (Member 4)        ├─► aes_encrypt  (Member 1)       │
 │        ▲                               └─► aes_decrypt  (Member 2)       │
 │        └──────────── 19-byte reply ◄───────────┘                         │
 └──────────────────────────────────────────────────────────────────────────┘
```

## Team
| Member | Part | Folder |
|---|---|---|
| Member 1 | AES encryption core + shared key expansion | `rtl/encryption/`, `rtl/common/` |
| Member 2 | AES decryption core | `rtl/decryption/` |
| Member 3 | UART + PC host program | `rtl/uart/`, `host/` |
| Member 4 | Top-level integration, board files, testing | `rtl/top/`, `quartus/`, `constraints/`, `tb/`, `sim/` |

## Repository layout
```
rtl/common/       aes_key_expansion.v (shared by encrypt and decrypt)
rtl/encryption/   aes_encrypt.v + SubBytes, ShiftRows, MixColumns, AddRoundKey, S-box
rtl/decryption/   aes_decrypt.v + controller and the inverse round functions
rtl/uart/         uart_rx/tx, baud generator, packet parser/sender, uart_interface
rtl/top/          aes_top.v wiring aes_controller, input_registers, mode_selector,
                  output_registers, status_leds; de10_lite_top.v board wrapper with
                  seven_segment_display
quartus/          Quartus Prime project (aes128.qpf / aes128.qsf)
constraints/      de10_lite.sdc (50 MHz timing)
tb/               tb_aes_encrypt, tb_aes_decrypt, tb_aes_cores, tb_uart, tb_aes_top
sim/run_sim.ps1   runs all simulations
host/             aes_uart_demo.py (PC-side program) + requirements.txt
docs/             architecture.md, uart_protocol.md, pin_connections.md
```
`README_FIRST.txt` is Member 1's original hand-off note, kept for reference.
More detail: [architecture](docs/architecture.md) · [UART protocol](docs/uart_protocol.md) · [pin connections](docs/pin_connections.md).

## UART protocol
| | Bytes | Layout |
|---|---|---|
| Request | 35 | `A5 5A CMD KEY[16] DATA[16]`, CMD `01` = encrypt, `02` = decrypt |
| Response | 19 | `5A A5 STATUS RESULT[16]`, STATUS `00` = OK, `01` = invalid command (result all zero) |

Byte 0 of each 16-byte block is sent first and maps to bit [127:120]. One request at a time: wait for the reply before sending the next.

## 1. Simulate (no board needed)
Install Icarus Verilog once (`winget install Icarus.Verilog`), then from the repo folder:
```
powershell -ExecutionPolicy Bypass -File sim\run_sim.ps1
```
Expected output ends with `ALL TESTBENCHES PASSED`: 64 checks across 5 testbenches, using FIPS-197 and NIST SP 800-38A test vectors.

## 2. Build for the DE10-Lite
1. Install **Quartus Prime Lite** with **MAX 10** device support.
2. Open `quartus/aes128.qpf`.
3. Processing → **Start Compilation**.
4. Check **Timing Analyzer** → the `clk50` clock should have positive slack.
5. Tools → **Programmer** → select `quartus/output_files/aes128.sof` → Start (USB-Blaster).

Board signals: **KEY0** = reset (press after any interrupted transfer), **LEDR0** = busy, **LEDR1** = last command was invalid, **LEDR2** = result ready, **LEDR9** = heartbeat blink, **HEX5–HEX0** = first 3 bytes of the last result (`69C4E0` after the encrypt demo below).

## 3. Wire up the UART
The DE10-Lite has no USB-serial chip. Use a **3.3 V** USB-to-TTL adapter (never 5 V):

| Adapter | DE10-Lite GPIO header |
|---|---|
| TX | GPIO[0] (pin 1, FPGA receives) |
| RX | GPIO[1] (pin 2, FPGA sends) |
| GND | any GND pin |

## 4. Run the demo from a PC
```
python -m pip install -r host/requirements.txt
```
Find the adapter's port: on Windows, Device Manager → Ports (e.g. `COM5`); on macOS, `ls /dev/cu.*`.
```
python host/aes_uart_demo.py COM5 encrypt --key 000102030405060708090A0B0C0D0E0F --data 00112233445566778899AABBCCDDEEFF
```
Expected: `Status: 0x00 (success)` and `Result: 69C4E0D86A7B0430D8CDB78070B4C55A`.
```
python host/aes_uart_demo.py COM5 decrypt --key 000102030405060708090A0B0C0D0E0F --data 69C4E0D86A7B0430D8CDB78070B4C55A
```
Expected result: `00112233445566778899AABBCCDDEEFF`.

## Status
| Item | State |
|---|---|
| Encryption, decryption, key expansion RTL | ✅ done, pass FIPS-197 test vectors in simulation |
| UART + host program | ✅ done, packet format checked against the RTL |
| Top-level integration, LEDs, 7-segment display | ✅ done |
| Testbenches | ✅ 5 testbenches, 64/64 simulation checks pass |
| Quartus compile + timing at 50 MHz | ⏳ not yet run |
| Test on real DE10-Lite board | ⏳ not yet run |
| Board choice (DE10-Lite) | ⏳ team to confirm |
