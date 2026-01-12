#!/bin/bash
# Ralph Wiggum: Claude Code Agent Adapter
#
# Adapter for Anthropic's Claude Code CLI.
#
# CLI: claude
# Output: stream-json format (via --output-format)
# Docs: https://docs.anthropic.com/claude-code

# =============================================================================
# AGENT INTERFACE IMPLEMENTATION
# =============================================================================

# Human-readable agent name
agent_name() {
  echo "Claude Code"
}

# CLI command name
agent_cli_name() {
  echo "claude"
}

# Check if agent CLI is installed
agent_check() {
  command -v claude &> /dev/null
}

# Get available models for this agent
agent_get_models() {
  local models=(
    "claude-sonnet-4-20250514"
    "claude-opus-4-20250514"
    "claude-3-5-sonnet-20241022"
    "claude-3-5-haiku-20241022"
  )
  echo "${models[@]}"
}

# Get default model
agent_default_model() {
  echo "claude-sonnet-4-20250514"
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

  # Claude Code uses -p for print mode (non-interactive)
  # --output-format stream-json for streaming JSON output
  local cmd="claude -p --output-format stream-json --model $model"

  # Claude Code uses --resume for session continuation
  if [[ -n "$session_id" ]]; then
    cmd="$cmd --resume \"$session_id\""
  fi

  # Allow all tools for autonomous operation
  cmd="$cmd --dangerously-skip-permissions"

  echo "$cmd"
}

# Get installation instructions
agent_install_instructions() {
  cat << 'EOF'
Install Claude Code CLI:

  npm install -g @anthropic-ai/claude-code

Then authenticate:

  claude login

For more info: https://docs.anthropic.com/claude-code
EOF
}
