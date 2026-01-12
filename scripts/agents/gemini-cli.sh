#!/bin/bash
# Ralph Wiggum: Gemini CLI Agent Adapter
#
# Adapter for Google's Gemini CLI.
#
# CLI: gemini
# Output: stream-json format (via --output-format)
# Docs: https://github.com/google-gemini/gemini-cli
#       https://geminicli.com/docs/cli/headless/

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

  # Gemini CLI uses -p for prompt/non-interactive mode
  # --output-format stream-json provides newline-delimited JSON events
  # -m for model selection
  local cmd="gemini -p --output-format stream-json -m $model"

  # --yolo auto-approves tool operations (similar to --dangerously-skip-permissions)
  cmd="$cmd --yolo"

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
