AES-128 FPGA — Member 1 starter files

Folders:
- rtl/encryption/: six forward AES/encryption modules
- rtl/common/: shared AES-128 key expansion module

Important:
- These files were extracted from the code supplied in the conversation.
- The supplied code has NOT yet been compiled or simulated.
- Do not assume it is error-free until the later testing phase.
- Keep the exact module names, port names, widths, byte ordering and round-key bus ordering from the team specification.
- aes_key_expansion.v is shared with Member 2. Send them this exact file; do not let them independently recreate it.
- aes_encrypt.v expects the round_keys bus to remain stable while busy is high.
- This is source code only; it does not include testbenches, board constraints, UART, or top-level integration.

Open the extracted AES128_Member1_Starter folder in VS Code.
