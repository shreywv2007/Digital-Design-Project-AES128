# AES-128 Decryption — Member 2

This folder contains the AES-128 decryption RTL modules.

Modules:
- aes_inv_sbox.v
- inv_sub_bytes.v
- inv_shift_rows.v
- inv_mix_columns.v
- inv_add_round_key.v
- aes_decrypt.v
- aes_decrypt_controller.v

The decryption core uses the shared AES-128 key expansion.
