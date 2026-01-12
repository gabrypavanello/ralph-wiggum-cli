#!/bin/bash
# Ralph Wiggum: Gemini CLI Agent Adapter
#
# Adapter for Google's Gemini CLI.
#
# CLI: gemini
# Output: stream-json format (via --output-format)
# Docs: https://github.com/google-gemini/gemini-cli

# =============================================================================
# AGENT INTERFACE IMPLEMENTATION
# =============================================================================

# Human-readable agent name
agent_name() {
  echo "Gemini CLI"
}

# CLI command name
agent_cli_name() {
  echo "gemini"
}

# Check if agent CLI is installed
agent_check() {
  command -v gemini &> /dev/null
}

# Get available models for this agent
agent_get_models() {
  local models=(
    "gemini-2.5-pro"
    "gemini-2.5-flash"
    "gemini-2.0-pro"
    "gemini-2.0-flash"
  )
  echo "${models[@]}"
}

# Get default model
agent_default_model() {
  echo "gemini-2.5-pro"
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

  # Gemini CLI supports --output-format stream-json for streaming JSON
  # Use -p for prompt mode (non-interactive, similar to other CLIs)
  local cmd="gemini -p --output-format stream-json --model $model"

  # Gemini CLI uses --sandbox=false to allow file operations
  cmd="$cmd --sandbox=false"

  # Resume session if provided
  if [[ -n "$session_id" ]]; then
    cmd="$cmd --resume \"$session_id\""
  fi

  echo "$cmd"
}

# Get installation instructions
agent_install_instructions() {
  cat << 'EOF'
Install Gemini CLI:

  npm install -g @google/gemini-cli

Then authenticate with your Google account:

  gemini auth login

Or set up API key:

  export GOOGLE_API_KEY=your_api_key

For more info: https://github.com/google-gemini/gemini-cli
EOF
}
