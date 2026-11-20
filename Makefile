.PHONY: test sounds hooks

# Plays every chapter in an isolated Neovim and checks known regressions
test:
	./tests/run.sh

# Rebuilds the music and sound effects
sounds:
	python3 lua/vimquest/sfx/generate.py

# Turns on the fast pre-commit syntax check for this clone
hooks:
	git config core.hooksPath .githooks
