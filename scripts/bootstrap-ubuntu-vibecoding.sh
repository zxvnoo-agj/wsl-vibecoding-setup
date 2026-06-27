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
OPTIONAL_FAILURES=()

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
  echo "Create a normal user first, add it to sudo, set /etc/wsl.conf [user] default=<name>, then run wsl.exe --shutdown." >&2
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

run_optional_stage() {
  local name="$1"
  shift
  log "$name"
  if "$@"; then
    echo "$name: OK"
  else
    warn "$name failed. Base environment remains usable; rerun this optional stage after fixing the error."
    OPTIONAL_FAILURES+=("$name")
  fi
}

install_base_packages() {
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

  if ! command_exists fd && command_exists fdfind; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi
}

configure_git_defaults() {
  git config --global init.defaultBranch main
  git config --global pull.rebase false
  if [ -n "${GIT_USER_NAME:-}" ]; then
    git config --global user.name "$GIT_USER_NAME"
  fi
  if [ -n "${GIT_USER_EMAIL:-}" ]; then
    git config --global user.email "$GIT_USER_EMAIL"
  fi
}

install_github_cli() {
  sudo mkdir -p -m 755 /etc/apt/keyrings
  local tmp_key
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
}

install_node_with_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  mkdir -p "$NVM_DIR"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    local nvm_install
    nvm_install="$(mktemp)"
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" -o "$nvm_install"
    bash "$nvm_install"
    rm -f "$nvm_install"
  fi

  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
  nvm install "$NODE_VERSION"
  nvm alias default "$NODE_VERSION"
  nvm use default
  hash -r
  corepack enable || true
}

configure_npm_registry() {
  if [ -n "$NPM_REGISTRY" ]; then
    npm config set registry "$NPM_REGISTRY"
    npm config get registry
  fi
}

check_node_path_pollution() {
  local node_path npm_path
  node_path="$(command -v node || true)"
  npm_path="$(command -v npm || true)"
  echo "node path: ${node_path:-missing}"
  echo "npm path: ${npm_path:-missing}"

  case "$node_path" in
    /mnt/*) warn "node resolves to a Windows-mounted path. Load nvm earlier in .bashrc or remove Windows Node from WSL PATH." ;;
  esac
  case "$npm_path" in
    /mnt/*) warn "npm resolves to a Windows-mounted path. Load nvm earlier in .bashrc or remove Windows npm from WSL PATH." ;;
  esac
}

install_opencode_cli() {
  curl -fsSL https://opencode.ai/install | bash
  command_exists opencode
  opencode --version || true
}

install_codex_cli() {
  local installer
  installer="$(mktemp)"

  if curl -fsSL https://chatgpt.com/codex/install.sh -o "$installer"; then
    if CODEX_NON_INTERACTIVE=1 sh "$installer"; then
      rm -f "$installer"
      command_exists codex
      codex --version || true
      return 0
    fi
  fi

  rm -f "$installer"
  warn "Codex standalone installer failed; falling back to npm install -g @openai/codex."
  command_exists npm
  npm install -g @openai/codex
  command_exists codex
  codex --version || true
}

install_claude_cli() {
  curl -fsSL https://claude.ai/install.sh | bash
  command_exists claude
  claude --version || true
}

write_shell_helpers() {
  mkdir -p "$HOME/.config/vibecoding"
  cat > "$HOME/.config/vibecoding/healthcheck.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$PROJECT_DIR"
command_exists() { command -v "\$1" >/dev/null 2>&1; }
echo "User: \$(id -un)"
git --version
node -v
npm -v
npm config get registry || true
rg --version | head -n 1
echo "node path: \$(command -v node || true)"
echo "npm path: \$(command -v npm || true)"
command -v codex || true
if command_exists codex; then codex --version || true; else echo "codex: not installed"; fi
if command_exists opencode; then opencode --version || true; else echo "opencode: not installed"; fi
if command_exists claude; then claude --version || true; else echo "claude: not installed"; fi
if command_exists gh; then gh --version | head -n 1; else echo "gh: not installed"; fi
if command_exists code; then code --version | head -n 1; else echo "code: not available in WSL shell"; fi
ls -ld "\$PROJECT_DIR"
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
}

run_healthcheck() {
  "$HOME/.config/vibecoding/healthcheck.sh"
}

log "Stage: base packages"
install_base_packages

if [ "$SKIP_NETWORK_TEST" -eq 0 ]; then
  log "Stage: curl network tests"
  curl_test "https://github.com"
  curl_test "https://registry.npmmirror.com"
  curl_test "https://opencode.ai"
fi

log "Stage: project directory"
mkdir -p "$PROJECT_DIR"

log "Stage: Git defaults"
configure_git_defaults

if [ "$INSTALL_GH" -eq 1 ]; then
  run_optional_stage "Optional: GitHub CLI" install_github_cli
fi

log "Stage: nvm and Node.js"
install_node_with_nvm

log "Stage: npm registry"
configure_npm_registry

log "Stage: Node PATH check"
check_node_path_pollution

if [ "$INSTALL_OPENCODE" -eq 1 ]; then
  run_optional_stage "Optional: OpenCode CLI" install_opencode_cli
fi

if [ "$INSTALL_CODEX" -eq 1 ]; then
  run_optional_stage "Optional: Codex CLI" install_codex_cli
fi

if [ "$INSTALL_CLAUDE" -eq 1 ]; then
  run_optional_stage "Optional: Claude Code" install_claude_cli
fi

log "Stage: shell helpers"
write_shell_helpers

log "Stage: final healthcheck"
run_healthcheck

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

if [ "${#OPTIONAL_FAILURES[@]}" -gt 0 ]; then
  warn "Optional stages failed: ${OPTIONAL_FAILURES[*]}"
  warn "Base packages, project directory, nvm/Node, npm registry, and healthcheck were processed. Rerun after fixing network/auth/tool issues."
fi
