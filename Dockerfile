# VimQuest in a container: the editor, the game and every tool they need, without installing anything on your machine.
#
#   docker build -t vimquest https://github.com/MuhammadWaleed-Animations/VimQuest.git
#   docker run -it --rm -v vimquest-save:/home/vimquest/save vimquest
#
# See "Try it in Docker" in the README for sound and clean-up.
FROM debian:trixie-slim

# Tools the config uses: git for plugins, gcc/make for parsers and native plugins, Node/Python for language servers
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip tar gzip make gcc libc6-dev \
      ripgrep fd-find lazygit nodejs npm python3 python3-venv pulseaudio-utils \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd \
 && rm -rf /var/lib/apt/lists/*

# Neovim 0.12+ and the tree-sitter CLI come from their releases: Debian's are too old
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN case "$(dpkg --print-architecture)" in \
      amd64) nvim=x86_64 ts=x64 ;; \
      arm64) nvim=arm64 ts=arm64 ;; \
      *) echo "Unsupported CPU: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac \
 && curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$nvim.tar.gz" | tar -xz -C /opt \
 && ln -s "/opt/nvim-linux-$nvim/bin/nvim" /usr/local/bin/nvim \
 && curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-$ts.gz" | gunzip >/usr/local/bin/tree-sitter \
 && chmod +x /usr/local/bin/tree-sitter

RUN useradd --create-home --uid 1000 --shell /bin/bash vimquest
USER vimquest
WORKDIR /home/vimquest
ENV LANG=C.UTF-8 TERM=xterm-256color

COPY --chown=vimquest:vimquest . .config/nvim

# Same steps as install.sh: compose the sounds, then install plugins, language servers and parsers,
# so the container starts without downloading anything
RUN python3 .config/nvim/lua/vimquest/sfx/generate.py \
 && nvim --headless --cmd 'lua vim.fn.confirm = function() return 1 end' -c 'luafile .config/nvim/scripts/bootstrap.lua' \
 && rm -rf .npm .cache

# Progress lives in ~/save, so a volume mounted there keeps it between runs
RUN mkdir save && ln -s /home/vimquest/save/vimquest.json .local/share/nvim/vimquest.json

# scripts/docker.lua gives the container a clipboard
ENTRYPOINT ["nvim", "--cmd", "luafile /home/vimquest/.config/nvim/scripts/docker.lua"]
