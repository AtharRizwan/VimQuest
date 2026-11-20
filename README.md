# VimQuest

**A ready-to-code Neovim setup, plus a story-mode pixel-art game that teaches you how to use it.**

Never used Vim? Can't even quit it? Perfect. Install with one command, type `:VimQuest`, and learn
Vim by playing: sneak past the Mouse Guard, squash the Bug Swarm, outsmart Lord Clickmore, and
escape the Void, all while your fingers learn real Neovim.

## Install

macOS or Linux (Ubuntu/Debian, Fedora, Arch):

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/MuhammadWaleed-Animations/VimQuest/main/install.sh)"
```

The installer:

- installs **Neovim** (0.12+) and the tools it needs: git, ripgrep, fd, Node, Python, lazygit, tree-sitter
  (Homebrew on macOS; apt, dnf or pacman on Linux)
- installs the **JetBrainsMono Nerd Font** so icons display correctly
- **backs up** your existing `~/.config/nvim` to `~/.config/nvim.backup-<date>` (nothing is deleted)
- installs every plugin, language server and syntax parser
- composes the game's soundtrack and sound effects locally (no audio is downloaded)

Afterwards, set your terminal's font to **JetBrainsMono Nerd Font**, then run `nvim` and type `:VimQuest`.

Running the installer again updates an existing VimQuest install.

## The game

| | |
|---|---|
| **Act I** (chapters 1–7) | Moving, words, deleting, insert mode, search, undo, the boss fight |
| **Act II** (chapters 8–13) | Copy/paste, replace, jumps, change, substitute, files, options, help, windows |
| **The Void** (secret) | Collect all 7 runes to find out how to *really* exit Vim |
| **Bonus chapters** | Real-world Neovim: creating and naming files, the file tree, fuzzy finding, buffers, splits, terminal |

Every chapter has its own pixel art, story, chiptune soundtrack and sound effects. Hints appear the
first time you meet each key, so absolute beginners can play from minute one. VimQuest covers everything
in `vimtutor`.

| Command | What it does |
|---|---|
| `:VimQuest` | Open the game menu |
| `:VimQuest easy` | Toggle easy mode (no chasers or timers) |
| `:VimQuest calm` | Toggle calm mode (no flicker or jump scares) |
| `:VimQuest music` | Toggle the music |
| `:VimQuest sound` | Toggle all sound |
| `:VimQuest credits` | Roll the credits |
| `:VimQuest reset` | Reset your progress |

## What's in the editor

Built on [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim), with:

- **Languages:** Python (Flask/Jinja), JavaScript, TypeScript, React, Next.js and Tailwind, with language servers,
  linting and format-on-save
- **Finding things:** `Space sf` find files, `Space sg` search text, `Space Space` open buffers
- **File tree:** `\` toggles neo-tree
- **Git:** `Space gg` lazygit, gitsigns in the gutter
- **Extras:** dashboard, buffer tabs (`Shift-h`/`Shift-l`), floating terminal (`Ctrl-\`), zen mode (`Space z`),
  flash jumps (`S`), diagnostics list (`Space xx`), auto-pairs, auto-closing tags, smooth cursor

Press `Space` and wait to see every shortcut.

## Contributing

Pull requests are welcome: new chapters, new bosses, fixes. Run the tests before opening one:

```sh
make test
```

The suite plays all 14 story chapters with real keystrokes, opens every story page, and checks known
regressions. It runs in an isolated Neovim with its own temporary save folder, so your own progress is never
touched. The same tests run automatically on every push and pull request.

## Credits

| Role | |
|---|---|
| Directed by | Muhammad Waleed |
| Written by | Muhammad Waleed |
| Lead Programmer | Muhammad Waleed |
| Pixel Artist | Muhammad Waleed |
| Composer & Sound Designer | Muhammad Waleed |
| Lead Bug Creator | Muhammad Waleed |
| Lead Bug Fixer | Muhammad Waleed |
| Person Who Still Can't Exit Vim | Muhammad Waleed |

No mice were harmed in the making of this game.

Questions, ideas, bugs, or just want to say hi: **muhammadwaleed6824@gmail.com**

## License

[MIT](LICENSE) © 2026 Muhammad Waleed. The editor configuration is based on
[kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) (MIT).
