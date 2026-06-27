#!/usr/bin/env bash
set -euo pipefail

NODE_VERSION="24"
PROJECT_DIR="$HOME/code"
NPM_REGISTRY="https://registry.npmmirror.com"
INSTALL_OPENCODE=0
INSTALL_CODEX=0
INSTALL_CLAUDE=0
INSTALL_GH=0
SKIP_NETWORK_TEST=0
NVM_VERSION="v0.40.5"

usage() {
  cat <<'USAGE'
Usage: bootstrap-ubuntu-vibecoding.sh [options]

Options:
  --node-version VERSION   Node version for nvm, default: 24
  --project-dir PATH      Project root to create, default: ~/code
  --npm-registry URL      npm registry mirror, default: https://registry.npmmirror.com
  --no-npm-mirror         Leave npm registry unchanged
  --install-opencode      Install OpenCode CLI
  --install-codex         Install OpenAI Codex CLI
  --install-claude        Install Claude Code
  --install-gh            Install GitHub CLI
  --skip-network-test     Skip curl connectivity tests
  -h, --help              Show this help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --node-version)
      NODE_VERSION="${2:?Missing value for --node-version}"
      shift 2
      ;;
    --project-dir)
      PROJECT_DIR="${2:?Missing value for --project-dir}"
      shift 2
      ;;
    --npm-registry)
      NPM_REGISTRY="${2:?Missing value for --npm-registry}"
      shift 2
      ;;
    --no-npm-mirror)
      NPM_REGISTRY=""
      shift
      ;;
    --install-opencode)
      INSTALL_OPENCODE=1
      shift
      ;;
    --install-codex)
      INSTALL_CODEX=1
      shift
      ;;
    --install-claude)
      INSTALL_CLAUDE=1
      shift
      ;;
    --install-gh)
      INSTALL_GH=1
      shift
      ;;
    --skip-network-test)
      SKIP_NETWORK_TEST=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this script as your normal Ubuntu user, not root." >&2
  exit 1
fi

PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"

log() {
  printf '\n==> %s\n' "$1"
}

warn() {
  printf 'WARN: %s\n' "$1" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

curl_test() {
  local url="$1"
  if curl -fsSI --connect-timeout 10 --max-time 20 "$url" >/dev/null; then
    echo "curl OK: $url"
  else
    warn "curl failed: $url"
  fi
}

log "Updating apt packages"
sudo apt update
sudo apt install -y \
  build-essential \
  ca-certificates \
  curl \
  fd-find \
  fzf \
  git \
  gnupg \
  jq \
  lsb-release \
  pipx \
  python3 \
  python3-pip \
  ripgrep \
  software-properties-common \
  unzip \
  wget \
  zip

if [ "$SKIP_NETWORK_TEST" -eq 0 ]; then
  log "Testing network connectivity with curl"
  curl_test "https://github.com"
  curl_test "https://registry.npmmirror.com"
  curl_test "https://opencode.ai"
fi

log "Preparing project directory"
mkdir -p "$PROJECT_DIR"

log "Configuring Git defaults"
git config --global init.defaultBranch main
git config --global pull.rebase false
if [ -n "${GIT_USER_NAME:-}" ]; then
  git config --global user.name "$GIT_USER_NAME"
fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then
  git config --global user.email "$GIT_USER_EMAIL"
fi

if [ "$INSTALL_GH" -eq 1 ]; then
  log "Installing GitHub CLI"
  sudo mkdir -p -m 755 /etc/apt/keyrings
  tmp_key="$(mktemp)"
  wget -nv -O "$tmp_key" https://cli.github.com/packages/githubcli-archive-keyring.gpg
  cat "$tmp_key" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  rm -f "$tmp_key"
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  sudo mkdir -p -m 755 /etc/apt/sources.list.d
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt update
  sudo apt install -y gh
fi

log "Installing nvm and Node.js"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi
# shellcheck source=/dev/null
. "$NVM_DIR/nvm.sh"
nvm install "$NODE_VERSION"
nvm alias default "$NODE_VERSION"
nvm use default
corepack enable || true

if [ -n "$NPM_REGISTRY" ]; then
  log "Configuring npm registry mirror"
  npm config set registry "$NPM_REGISTRY"
  npm config get registry
fi

if [ "$INSTALL_OPENCODE" -eq 1 ]; then
  log "Installing OpenCode CLI"
  curl -fsSL https://opencode.ai/install | bash
fi

if [ "$INSTALL_CODEX" -eq 1 ]; then
  log "Installing OpenAI Codex CLI"
  curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
fi

if [ "$INSTALL_CLAUDE" -eq 1 ]; then
  log "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
fi

log "Adding small shell helpers"
mkdir -p "$HOME/.config/vibecoding"
cat > "$HOME/.config/vibecoding/healthcheck.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "User: $(id -un)"
echo "Kernel: $(uname -a)"
git --version
node -v
npm -v
npm config get registry || true
rg --version | head -n 1
command -v code >/dev/null 2>&1 && code --version | head -n 1 || true
command -v cursor >/dev/null 2>&1 && cursor --version | head -n 1 || true
command -v gh >/dev/null 2>&1 && gh --version | head -n 1 || true
command -v opencode >/dev/null 2>&1 && opencode --version || true
command -v codex >/dev/null 2>&1 && codex --version || true
command -v claude >/dev/null 2>&1 && claude --version || true
EOF
chmod +x "$HOME/.config/vibecoding/healthcheck.sh"

if ! grep -q "vibecoding WSL setup" "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" <<EOF

# >>> vibecoding WSL setup >>>
export EDITOR="\${EDITOR:-code}"
croot() { cd "$PROJECT_DIR"; }
alias vibecoding-health="$HOME/.config/vibecoding/healthcheck.sh"
# <<< vibecoding WSL setup <<<
EOF
fi

log "Versions"
git --version
node -v
npm -v
npm config get registry || true
rg --version | head -n 1
if command_exists gh; then gh --version | head -n 1; fi
if command_exists opencode; then opencode --version || true; fi
if command_exists codex; then codex --version || true; fi
if command_exists claude; then claude --version || true; fi

cat <<EOF

Setup complete.

Next interactive steps:
  cd "$PROJECT_DIR"
  gh auth login        # if GitHub CLI was installed
  opencode             # if OpenCode CLI was installed; run /connect when prompted
  codex                # if Codex CLI was installed
  claude               # if Claude Code was installed
  code .               # open this WSL folder in VS Code from Windows

Health check:
  vibecoding-health
EOF
