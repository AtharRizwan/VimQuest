#!/usr/bin/env bash
# VimQuest installer: Neovim, tools, a Nerd Font, this config, plugins, language servers and the game
set -euo pipefail

REPO="${VIMQUEST_REPO:-https://github.com/MuhammadWaleed-Animations/VimQuest.git}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
BIN="$HOME/.local/bin"
NVIM_MIN_MINOR=12

bold=$'\033[1m'; gold=$'\033[33m'; green=$'\033[32m'; red=$'\033[31m'; dim=$'\033[2m'; off=$'\033[0m'
say() { printf '%s▸ %s%s\n' "$gold$bold" "$*" "$off"; }
ok() { printf '%s✓ %s%s\n' "$green" "$*" "$off"; }
warn() { printf '%s! %s%s\n' "$red" "$*" "$off"; }
has() { command -v "$1" >/dev/null 2>&1; }
sudo_() { if [ "$(id -u)" -eq 0 ]; then "$@"; elif has sudo; then sudo "$@"; else warn "need root for: $*"; return 1; fi; }

cat <<'EOF'

  ██╗   ██╗██╗███╗   ███╗ ██████╗ ██╗   ██╗███████╗███████╗████████╗
  ██║   ██║██║████╗ ████║██╔═══██╗██║   ██║██╔════╝██╔════╝╚══██╔══╝
  ██║   ██║██║██╔████╔██║██║   ██║██║   ██║█████╗  ███████╗   ██║
  ╚██╗ ██╔╝██║██║╚██╔╝██║██║▄▄ ██║██║   ██║██╔══╝  ╚════██║   ██║
   ╚████╔╝ ██║██║ ╚═╝ ██║╚██████╔╝╚██████╔╝███████╗███████║   ██║
    ╚═══╝  ╚═╝╚═╝     ╚═╝ ╚══▀▀═╝  ╚═════╝ ╚══════╝╚══════╝   ╚═╝
        A ready-to-code Neovim setup + a game that teaches it

EOF

nvim_ok() {
  has nvim || return 1
  local minor
  minor=$(nvim --version | head -1 | sed -E 's/^NVIM v0\.([0-9]+).*/\1/')
  [ "${minor:-0}" -ge "$NVIM_MIN_MINOR" ] 2>/dev/null
}

add_to_path() {
  mkdir -p "$BIN"
  case ":$PATH:" in *":$BIN:"*) ;; *) export PATH="$BIN:$PATH" ;; esac
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$rc" ] && ! grep -q 'VimQuest: local bin' "$rc"; then
      printf '\nexport PATH="$HOME/.local/bin:$PATH" # VimQuest: local bin\n' >>"$rc"
    fi
  done
}

install_mac() {
  if ! has brew; then
    say "Installing Homebrew (it may ask for your password)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
  local want=() cmd pkg
  for pair in nvim:neovim git:git rg:ripgrep fd:fd node:node python3:python lazygit:lazygit tree-sitter:tree-sitter-cli; do
    cmd=${pair%%:*}; pkg=${pair#*:}
    if [ "$cmd" = nvim ]; then nvim_ok || want+=("$pkg"); else has "$cmd" || want+=("$pkg"); fi
  done
  if [ ${#want[@]} -gt 0 ]; then say "brew install ${want[*]}"; brew install "${want[@]}"; fi
  if ! brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
    say "Installing JetBrainsMono Nerd Font (for icons)"
    brew install --cask font-jetbrains-mono-nerd-font || warn "Font install failed, icons may look like boxes"
  fi
}

install_linux_nvim() {
  nvim_ok && return
  local arch
  case "$(uname -m)" in x86_64 | amd64) arch=x86_64 ;; aarch64 | arm64) arch=arm64 ;; *) warn "Unsupported CPU, install Neovim 0.$NVIM_MIN_MINOR+ yourself"; return 1 ;; esac
  say "Downloading the latest Neovim ($arch)"
  mkdir -p "$HOME/.local/opt"
  curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$arch.tar.gz" | tar -xz -C "$HOME/.local/opt"
  ln -sf "$HOME/.local/opt/nvim-linux-$arch/bin/nvim" "$BIN/nvim"
}

install_linux() {
  if has apt-get; then
    say "Installing tools with apt"
    sudo_ apt-get update -qq
    sudo_ env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git curl unzip tar gzip make gcc ripgrep fd-find nodejs npm python3 alsa-utils fontconfig xclip
    has fd || { has fdfind && ln -sf "$(command -v fdfind)" "$BIN/fd"; }
  elif has dnf; then
    say "Installing tools with dnf"
    sudo_ dnf install -y -q git curl unzip tar gzip make gcc ripgrep fd-find nodejs npm python3 alsa-utils fontconfig xclip
  elif has pacman; then
    say "Installing tools with pacman"
    sudo_ pacman -Sy --needed --noconfirm git curl unzip tar gzip make gcc ripgrep fd nodejs npm python alsa-utils fontconfig xclip lazygit tree-sitter-cli
  else
    warn "Unknown package manager: install git, curl, make, gcc, ripgrep, fd, node, npm, python3 yourself"
  fi
  install_linux_nvim
  if ! has tree-sitter && has npm; then
    say "Installing tree-sitter CLI"
    npm install -g --silent --prefix "$HOME/.local" tree-sitter-cli || warn "tree-sitter CLI failed, syntax colors may be limited"
  fi
  local fonts="$HOME/.local/share/fonts/JetBrainsMonoNerd"
  if [ ! -d "$fonts" ]; then
    say "Installing JetBrainsMono Nerd Font (for icons)"
    mkdir -p "$fonts"
    if curl -fsSL -o /tmp/vimquest-font.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip; then
      unzip -oq /tmp/vimquest-font.zip -d "$fonts" && rm -f /tmp/vimquest-font.zip
      has fc-cache && fc-cache -f "$fonts" >/dev/null || true
    else
      warn "Font download failed, icons may look like boxes"
    fi
  fi
}

# 1. Tools
add_to_path
if [ "${VIMQUEST_SKIP_DEPS:-0}" = 1 ]; then
  say "Skipping system tools (VIMQUEST_SKIP_DEPS=1)"
else
  case "$(uname -s)" in
    Darwin) install_mac ;;
    Linux) install_linux ;;
    *) warn "Unsupported system: $(uname -s)"; exit 1 ;;
  esac
fi
nvim_ok || { warn "Neovim 0.$NVIM_MIN_MINOR or newer is required"; exit 1; }
ok "Neovim $(nvim --version | head -1 | cut -d' ' -f2)"

# 2. Config (your old one is backed up, never deleted)
here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -d "$CONFIG/.git" ] && git -C "$CONFIG" remote get-url origin 2>/dev/null | grep -qi vimquest; then
  say "Updating existing VimQuest config"
  git -C "$CONFIG" pull --ff-only
elif [ "$here" != "$CONFIG" ]; then
  if [ -e "$CONFIG" ]; then
    backup="$CONFIG.backup-$(date +%Y%m%d-%H%M%S)"
    say "Backing up your current config to $backup"
    mv "$CONFIG" "$backup"
  fi
  mkdir -p "$(dirname "$CONFIG")"
  if [ -n "$here" ] && [ -f "$here/init.lua" ] && [ -d "$here/lua/vimquest" ]; then
    say "Copying config from $here"
    cp -R "$here" "$CONFIG"
  else
    say "Downloading VimQuest"
    git clone --depth 1 "$REPO" "$CONFIG"
  fi
fi
ok "Config installed at $CONFIG"

# 3. Music and sound effects (synthesized locally, nothing downloaded)
if has python3; then
  say "Composing the soundtrack and sound effects"
  python3 "$CONFIG/lua/vimquest/sfx/generate.py" >/dev/null && ok "Sounds ready"
else
  warn "python3 not found, the game will be silent"
fi

# 4. Plugins, language servers and parsers
say "Installing plugins, language servers and parsers (a few minutes the first time)"
nvim --headless --cmd 'lua vim.fn.confirm = function() return 1 end' -c "luafile $CONFIG/scripts/bootstrap.lua" 2>&1 | grep -v '^$' | sed "s/^/$dim/;s/\$/$off/" || true
ok "Neovim is ready"

cat <<EOF

${green}${bold}All set!${off} Here is how to start playing:

  1. Set your terminal font to ${bold}JetBrainsMono Nerd Font${off} so icons show up
     ${dim}(macOS Terminal: Settings > Profiles > Text > Font > Change)${off}
  2. Open a ${bold}new${off} terminal window, type ${bold}nvim${off} and press Enter
  3. On the start screen, press ${bold}v${off} to Play VimQuest
     ${dim}(or type ${off}${bold}:VimQuest${off}${dim} and press Enter - the : is Shift + ;)${off}
  4. Pick a chapter with j / k and press Enter. The game teaches you the rest!

  To quit Neovim later: type ${bold}:qa${off} and press Enter.

  Your previous config (if any) was saved next to $CONFIG as nvim.backup-*

EOF
