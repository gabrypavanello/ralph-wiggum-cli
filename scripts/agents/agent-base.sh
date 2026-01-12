#!/bin/bash
# Ralph Wiggum: Agent Base
#
# Base functions for all agent adapters. Each agent adapter should source this
# file and implement the required functions.
#
# Required functions that each agent must implement:
#   - agent_name()        - Returns the human-readable agent name
#   - agent_cli_name()    - Returns the CLI command name
#   - agent_check()       - Check if agent CLI is installed (returns 0/1)
#   - agent_build_cmd()   - Build the command to run the agent
#   - agent_get_models()  - Return array of available models for this agent
#   - agent_default_model() - Return the default model name
#   - agent_output_format() - Return the output format type (stream-json, json, plain)

# =============================================================================
# AGENT REGISTRY
# =============================================================================

# List of available agents (order matters for UI)
AVAILABLE_AGENTS=(
  "cursor"
  "claude-code"
  "codex-cli"
  "gemini-cli"
  "copilot-cli"
)

# Agent display names
declare -A AGENT_DISPLAY_NAMES=(
  ["cursor"]="Cursor Agent"
  ["claude-code"]="Claude Code"
  ["codex-cli"]="OpenAI Codex CLI"
  ["gemini-cli"]="Gemini CLI"
  ["copilot-cli"]="GitHub Copilot CLI"
)

# =============================================================================
# AGENT LOADING
# =============================================================================

# Get the directory where agent scripts are located
get_agents_dir() {
  echo "$(dirname "${BASH_SOURCE[0]}")"
}

# Load a specific agent adapter
load_agent() {
  local agent_name="$1"
  local agents_dir=$(get_agents_dir)
  local agent_file="$agents_dir/${agent_name}.sh"

  if [[ ! -f "$agent_file" ]]; then
    echo "ERROR: Agent adapter not found: $agent_file" >&2
    return 1
  fi

  source "$agent_file"
}

# Get list of installed agents
get_installed_agents() {
  local installed=()
  local agents_dir=$(get_agents_dir)

  for agent in "${AVAILABLE_AGENTS[@]}"; do
    local agent_file="$agents_dir/${agent}.sh"
    if [[ -f "$agent_file" ]]; then
      source "$agent_file"
      if agent_check 2>/dev/null; then
        installed+=("$agent")
      fi
    fi
  done

  echo "${installed[@]}"
}

# Get display name for an agent
get_agent_display_name() {
  local agent="$1"
  echo "${AGENT_DISPLAY_NAMES[$agent]:-$agent}"
}

# =============================================================================
# COMMON AGENT HELPERS
# =============================================================================

# Check if a command exists
command_exists() {
  command -v "$1" &> /dev/null
}

# Get install instructions for an agent
get_install_instructions() {
  local agent="$1"

  case "$agent" in
    "cursor")
      echo "Install via: curl https://cursor.com/install -fsS | bash"
      ;;
    "claude-code")
      echo "Install via: npm install -g @anthropic-ai/claude-code"
      ;;
    "codex-cli")
      echo "Install via: npm install -g @openai/codex"
      ;;
    "gemini-cli")
      echo "Install via: npm install -g @google/gemini-cli"
      ;;
    "copilot-cli")
      echo "Install via: npm install -g @github/copilot"
      ;;
    *)
      echo "See agent documentation for installation instructions"
      ;;
  esac
}
