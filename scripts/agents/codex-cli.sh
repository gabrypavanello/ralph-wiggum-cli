#!/bin/bash
# Ralph Wiggum: OpenAI Codex CLI Agent Adapter
#
# Adapter for OpenAI's Codex CLI.
#
# CLI: codex
# Output: JSON via --json flag (newline-delimited JSON events)
# Docs: https://github.com/openai/codex
#       https://developers.openai.com/codex/cli/
#
# Note: Codex uses `codex exec` for headless mode (not -p like other CLIs)

# =============================================================================
# AGENT INTERFACE IMPLEMENTATION
# =============================================================================

# Human-readable agent name
agent_name() {
  echo "OpenAI Codex CLI"
}

# CLI command name
agent_cli_name() {
  echo "codex"
}

# Check if agent CLI is installed
agent_check() {
  command -v codex &> /dev/null
}

# Get available models for this agent
agent_get_models() {
  local models=(
    "gpt-5-codex"
    "gpt-5"
    "o3"
    "o3-mini"
    "gpt-4.1"
  )
  echo "${models[@]}"
}

# Get default model
agent_default_model() {
  echo "gpt-5-codex"
}

# Get output format type
agent_output_format() {
  echo "stream-json"
}

# Build the command to run the agent
# Args: $1 = model, $2 = session_id (optional)
# Returns: command string (prompt will be passed as argument)
agent_build_cmd() {
  local model="$1"
  local session_id="${2:-}"

  # Codex uses `exec` subcommand for headless/non-interactive mode
  # --json streams newline-delimited JSON events to stdout
  # --model for model selection
  local cmd="codex exec --json --model $model"

  # --full-auto bypasses approval prompts for autonomous operation
  cmd="$cmd --full-auto"

  # Resume session if provided
  if [[ -n "$session_id" ]]; then
    cmd="codex exec resume --last --json --model $model --full-auto"
  fi

  echo "$cmd"
}

# Get installation instructions
agent_install_instructions() {
  cat << 'EOF'
Install OpenAI Codex CLI:

  npm install -g @openai/codex

Or on macOS:

  brew install --cask codex

Then authenticate:

  codex

(Follow the prompts to sign in with ChatGPT or use an API key)

For more info: https://github.com/openai/codex
EOF
}
