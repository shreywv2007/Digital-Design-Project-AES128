# Architecture

The design receives one AES-128 request over UART, runs it through an encryption or decryption core, and sends one reply back. Everything runs on a single 50 MHz clock with a synchronous, active-high reset.

## Block diagram
```
                     ┌──────────────────────────── aes_top ─────────────────────────────┐
 UART_RXD ──► uart_interface ── command/key/data ──► input_registers ──► aes_key_expansion
 (GPIO[0])    (Member 3)        packet_valid/error        │  ▲  round keys ◄──┘  (Member 1)
                  ▲                                       │  │
                  │                                 data, │  │ round_keys (registered)
                  │                                       ▼  │
                  │                              ┌── aes_encrypt (Member 1) ──┐
                  │                              │                            ├─► mode_selector
                  │                              └── aes_decrypt (Member 2) ──┘        │
                  │                                                              core_result
 UART_TXD ◄── status/result ◄───────────── output_registers ◄─────────────────────────┘
 (GPIO[1])
                  aes_controller sequences every step  ·  status_leds drives LEDR
                     └──────────────────────────────────────────────────────────────────┘
 de10_lite_top adds: reset synchroniser (KEY0), seven_segment_display (HEX5..HEX0)
```

## Modules
| Module | Owner | Job |
|---|---|---|
| `aes_key_expansion` | Member 1 | Combinational: 128-bit key → 11 round keys (1408 bits), `K[r] = round_keys[128*r +: 128]` |
| `aes_encrypt` | Member 1 | Iterative encryption, one round per clock; `done` 11 clocks after `start` |
| `aes_sbox`, `sub_bytes`, `shift_rows`, `mix_columns`, `add_round_key` | Member 1 | Round functions |
| `aes_decrypt` + `aes_decrypt_controller` | Member 2 | Iterative inverse cipher; `done` 12 clocks after `start` |
| `aes_inv_sbox`, `inv_sub_bytes`, `inv_shift_rows`, `inv_mix_columns`, `inv_add_round_key` | Member 2 | Inverse round functions |
| `uart_interface` (+ `uart_rx`, `uart_tx`, `baud_generator`, `uart_packet_parser`, `uart_packet_sender`) | Member 3 | 115200 8-N-1 serial, packet framing (see `uart_protocol.md`) |
| `aes_controller` | Member 4 | Main state machine (below) |
| `input_registers` | Member 4 | Holds command/key/data and the registered round keys stable during a run |
| `mode_selector` | Member 4 | Sends `start` to the right core, picks that core's `done` and result |
| `output_registers` | Member 4 | Holds status + result for the reply and the display |
| `status_leds` | Member 4 | Busy / error / done / heartbeat LEDs |
| `seven_segment_display` | Member 4 | Shows the first 3 result bytes on HEX5..HEX0 |
| `aes_top` | Member 4 | Wires all of the above together |
| `de10_lite_top` | Member 4 | Board pins, reset synchroniser, 7-segment display |

## Controller state machine (`aes_controller`)
```
         packet_valid                         core_done
 IDLE ───────────────► EXPAND ──► START ──► RUN ─────────┐
  ▲  │                                                    ▼
  │  │ packet_error (status 01)                       RESPOND ──(!response_busy)──► WAIT_TX
  │  └───────────────────────────────────────────────────▲                            │
  └────────────────────────── response_done ─────────────────────────────────────────┘
```
| State | Output pulse | Meaning |
|---|---|---|
| IDLE | `load_inputs` or `capture_error` | Accept a request, or flag an invalid command |
| EXPAND | `expand_keys` | Store the 11 round keys (cuts the long key-expansion path from the AES datapath) |
| START | `core_start` | One-clock start to the selected core |
| RUN | `capture_result` | Core finished; store its output with status 00 |
| RESPOND | `response_start` | Ask the UART sender to transmit the 19-byte reply |
| WAIT_TX | – | Wait for the last stop bit, then accept the next request |

Requests that arrive while not in IDLE are ignored: the host must wait for each reply.

## Timing per request (50 MHz, 115200 baud)
| Step | Time |
|---|---|
| Receive 35 bytes | ≈ 3.04 ms |
| Key expansion + AES | 14 clocks ≈ 0.3 µs |
| Send 19 bytes | ≈ 1.65 ms |

The UART dominates; the AES itself is effectively instant.

## Verification
`sim/run_sim.ps1` runs five testbenches (Icarus Verilog):
| Testbench | What it checks |
|---|---|
| `tb_aes_encrypt` | FIPS-197 B, C.1 and NIST SP 800-38A ECB vectors; 11-clock latency; start ignored while busy |
| `tb_aes_decrypt` | Same vectors in reverse; 12-clock latency; ciphertext captured at start |
| `tb_aes_cores` | Key-expansion round keys, encrypt→decrypt round trips, mid-operation reset |
| `tb_uart` | Packet decoding, invalid command, junk + framing errors, 19-byte reply format |
| `tb_aes_top` | Whole design through the UART pins, LEDs and 7-segment output |
