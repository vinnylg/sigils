# totp

Terminal TOTP code generator for two-factor authentication.
Generate RFC 6238 time-based one-time passwords from the command line.

## Dependencies

- `oathtool` (oath-toolkit) — TOTP code generation
- `xclip` | `wl-copy` | `xsel` — clipboard support (optional, for `--clip`)

## Usage

```
totp add --name github --secret JBSWY3DPEHPK3PXP
totp add --uri "otpauth://totp/GitHub:user?secret=JBSWY3DPEHPK3PXP&issuer=GitHub"
totp list
totp get
totp get --name github --clip
totp export --name github
totp remove --name github
```

## Storage

Secrets are stored in `$XDG_CONFIG_HOME/sigils/totp/keys` (default `~/.config/sigils/totp/keys`)
with permissions `600`. The file uses a simple tab-separated format.
