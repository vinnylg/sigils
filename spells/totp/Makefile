.PHONY: test check fmt clean

test:
	@echo "[skip] no spell-local tests configured"

check:
	@command -v oathtool >/dev/null 2>&1 && echo "[ok] oathtool found" || echo "[fail] oathtool not found"
	@bash -n bin/totp && echo "[ok] bin/totp syntax valid" || echo "[fail] bin/totp syntax error"
	@bash -n completions/bash/totp.bash && echo "[ok] completions/bash/totp.bash syntax valid" || echo "[fail] completions syntax error"

fmt:
	@echo "[skip] no spell-local formatting configured"

clean:
	@echo "[skip] no spell-local cleanup configured"
