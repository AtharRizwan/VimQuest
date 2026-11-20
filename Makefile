.PHONY: test sounds

# Plays every chapter in an isolated Neovim and checks known regressions
test:
	./tests/run.sh

# Rebuilds the music and sound effects
sounds:
	python3 lua/vimquest/sfx/generate.py
