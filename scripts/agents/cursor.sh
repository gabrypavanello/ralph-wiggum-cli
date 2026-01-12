#!/bin/bash
# Ralph Wiggum: Cursor Agent Adapter
#
# Adapter for the Cursor CLI agent (cursor-agent).
# This is the original agent Ralph was built for.
#
# CLI: cursor-agent
# Output: stream-json format
# Docs: https://cursor.com/docs

# =============================================================================
# AGENT INTERFACE IMPLEMENTATION
# =============================================================================

# Human-readable agent name
agent_name() {
  echo "Cursor Agent"
}

# CLI command name
agent_cli_name() {
  echo "cursor-agent"
}

# Check if agent CLI is installed
agent_check() {
  command -v cursor-agent &> /dev/null
}

# Get available models for this agent
agent_get_models() {
  local models=(
    "opus-4.5-thinking"
    "sonnet-4.5-thinking"
    "gpt-5.2-high"
    "composer-1"
  )
  echo "${models[@]}"
}

# Get default model
agent_default_model() {
  echo "opus-4.5-thinking"
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

  local cmd="cursor-agent -p --force --output-format stream-json --model $model"

  if [[ -n "$session_id" ]]; then
    cmd="$cmd --resume=\"$session_id\""
  fi

  echo "$cmd"
}

# Get installation instructions
agent_install_instructions() {
  cat << 'EOF'
Install Cursor Agent CLI:

  curl https://cursor.com/install -fsS | bash

Or download from: https://cursor.com/download
EOF
}
