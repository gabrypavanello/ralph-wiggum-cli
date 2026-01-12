#!/bin/bash
# Ralph Wiggum: GitHub Copilot CLI Agent Adapter
#
# Adapter for GitHub's Copilot CLI.
#
# CLI: copilot
# Output: stream-json format (via --output-format)
# Docs: https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-in-the-command-line

# =============================================================================
# AGENT INTERFACE IMPLEMENTATION
# =============================================================================

# Human-readable agent name
agent_name() {
  echo "GitHub Copilot CLI"
}

# CLI command name
agent_cli_name() {
  echo "copilot"
}

# Check if agent CLI is installed
agent_check() {
  command -v copilot &> /dev/null
}

# Get available models for this agent
agent_get_models() {
  local models=(
    "claude-sonnet-4.5"
    "claude-sonnet-4"
    "gpt-5"
    "gpt-4o"
  )
  echo "${models[@]}"
}

# Get default model
agent_default_model() {
  echo "claude-sonnet-4.5"
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

  # Copilot CLI uses -p or --prompt for prompt mode
  # --output-format stream-json for streaming JSON
  local cmd="copilot -p --output-format stream-json --model $model"

  # Allow all tools for autonomous operation
  cmd="$cmd --allow-all-tools"

  # Resume session if provided (uses --continue for most recent or --resume for specific)
  if [[ -n "$session_id" ]]; then
    cmd="$cmd --resume \"$session_id\""
  fi

  echo "$cmd"
}

# Get installation instructions
agent_install_instructions() {
  cat << 'EOF'
Install GitHub Copilot CLI:

  npm install -g @github/copilot

Then authenticate with your GitHub account:

  copilot auth login

Requirements:
- GitHub account with Copilot subscription
- macOS, Linux, or Windows (WSL)

For more info: https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-in-the-command-line
EOF
}
