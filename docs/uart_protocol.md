# UART protocol

## Serial settings
- **115200 baud, 8 data bits, no parity, 1 stop bit (8-N-1)**, no flow control.
- 3.3 V logic levels. Bits inside each byte go LSB first (handled by the UART hardware).

## Request: PC → FPGA (35 bytes)
| Byte(s) | Value | Meaning |
|---|---|---|
| 0 | `A5` | Sync 1 |
| 1 | `5A` | Sync 2 |
| 2 | `01` / `02` | Command: `01` = encrypt, `02` = decrypt |
| 3 – 18 | key | 128-bit key, byte 3 = key[127:120] |
| 19 – 34 | data | Plaintext (encrypt) or ciphertext (decrypt), byte 19 = data[127:120] |

## Response: FPGA → PC (19 bytes)
| Byte(s) | Value | Meaning |
|---|---|---|
| 0 | `5A` | Sync 1 |
| 1 | `A5` | Sync 2 |
| 2 | status | `00` = success, `01` = invalid command |
| 3 – 18 | result | Ciphertext / plaintext; all zero when status ≠ `00` |

## Rules
- **One request at a time.** Wait for the full reply before sending the next request. Bytes received while the FPGA is busy are ignored.
- The parser searches for `A5 5A`, so junk bytes before a request are skipped.
- An unknown command byte gets an immediate status-`01` reply. The rest of that request's bytes are then scanned for a new `A5 5A`.
- There is no timeout. If a request is cut off partway, stop sending, wait for the line to go quiet, then **press KEY0 (reset)** before retrying.

## Example (FIPS-197 Appendix C.1)
Encrypt request:
```
A5 5A 01
00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
00 11 22 33 44 55 66 77 88 99 AA BB CC DD EE FF
```
Reply:
```
5A A5 00
69 C4 E0 D8 6A 7B 04 30 D8 CD B7 80 70 B4 C5 5A
```
Decrypting `69C4E0D86A7B0430D8CDB78070B4C55A` with the same key (command `02`) returns `00112233445566778899AABBCCDDEEFF`.

Invalid command (e.g. `07`) reply:
```
5A A5 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
```

## Host program
`host/aes_uart_demo.py` builds the request and checks the reply:
```
python -m pip install -r host/requirements.txt
python host/aes_uart_demo.py COM5 encrypt --key 000102030405060708090A0B0C0D0E0F --data 00112233445566778899AABBCCDDEEFF
```
(Use `/dev/cu.*` instead of `COM5` on macOS.)
