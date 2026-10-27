# Security Policy

## Public repository rules

This repository must never contain:

- Supabase secret/service-role keys or database passwords.
- Student records, answers, password hashes, or production exports.
- `.env` files, SQLite/PostgreSQL dumps, encrypted backup archives, or signing keystores.
- Local backup configuration under `.tools/`.

Only the Supabase project URL and publishable browser key may be present in client code. Privileged operations must remain inside the Supabase Edge Function and must validate the authenticated role.

## Reporting

Do not open a public issue containing credentials or personal data. Contact the repository owner privately, rotate any exposed credential immediately, and review Supabase and GitHub logs.

## Backup isolation

Plaintext operational backups must never be committed. With the project owner's explicit approval, automation may publish only the newest authenticated `.mnbak` ciphertext to the `encrypted-backup` branch. The recovery passphrase is never stored in GitHub, and the branch is replaced rather than accumulated. A public branch is not a privacy boundary, so a long unique recovery passphrase remains essential.
