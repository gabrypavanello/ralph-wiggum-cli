#!/bin/bash
# Ralph Wiggum: GitHub Copilot CLI Agent Adapter
#
# Adapter for GitHub's Copilot CLI.
#
# CLI: copilot
# Output: text (stream-json not yet supported - see github/copilot-cli#52)
# Docs: https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-in-the-command-line
#
# NOTE: GitHub Copilot CLI does not yet support --output-format stream-json.
# This adapter uses text output mode which provides limited token tracking.
# See: https://github.com/github/copilot-cli/issues/52

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
# Default is claude-sonnet-4.5, can be changed with /model command
agent_get_models() {
  local models=(
    "claude-sonnet-4.5"
    "claude-sonnet-4"
    "gpt-4o"
    "o1"
  )
  echo "${models[@]}"
}

# Get default model
agent_default_model() {
  echo "claude-sonnet-4.5"
}

# Get output format type
# NOTE: Copilot CLI does not support stream-json yet, using text
agent_output_format() {
  echo "text"
}

# Build the command to run the agent
# Args: $1 = model, $2 = session_id (optional)
# Returns: command string (prompt will be passed as argument)
agent_build_cmd() {
  local model="$1"
  local session_id="${2:-}"

  # Copilot CLI uses -p for prompt/non-interactive mode
  # Note: --output-format stream-json is NOT supported yet (github/copilot-cli#52)
  # Using text output mode - token tracking will be limited
  local cmd="copilot -p --model $model"

  # Allow all tools for autonomous operation
  cmd="$cmd --allow-all-tools"

  # Resume session if provided
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

NOTE: GitHub Copilot CLI does not yet support --output-format stream-json
(see github/copilot-cli#52). Token tracking will be limited.

For more info: https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-in-the-command-line
EOF
}
