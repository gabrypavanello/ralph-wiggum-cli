#!/bin/bash
# Ralph Wiggum: The Loop (CLI Mode)
#
# Runs AI coding agents locally with stream-json parsing for accurate token tracking.
# Handles context rotation via --resume when thresholds are hit.
#
# Supported agents: cursor, claude-code, gemini-cli, copilot-cli
#
# This script is for power users and scripting. For interactive use, see ralph-setup.sh.
#
# Usage:
#   ./ralph-loop.sh                              # Start from current directory
#   ./ralph-loop.sh /path/to/project             # Start from specific project
#   ./ralph-loop.sh -a claude-code -m claude-sonnet-4-20250514  # Use Claude Code
#   ./ralph-loop.sh -n 50 -m gpt-5.2-high        # Custom iterations and model
#   ./ralph-loop.sh --branch feature/foo --pr   # Create branch and PR
#   ./ralph-loop.sh -y                           # Skip confirmation (for scripting)
#
# Flags:
#   -a, --agent AGENT      Agent to use (cursor, claude-code, gemini-cli, copilot-cli)
#   -n, --iterations N     Max iterations (default: 20)
#   -m, --model MODEL      Model to use (defaults based on agent)
#   --branch NAME          Create and work on a new branch
#   --pr                   Open PR when complete (requires --branch)
#   -y, --yes              Skip confirmation prompt
#   -h, --help             Show this help
#
# Requirements:
#   - RALPH_TASK.md in the project root
#   - Git repository
#   - At least one supported agent CLI installed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "$SCRIPT_DIR/ralph-common.sh"

# =============================================================================
# FLAG PARSING
# =============================================================================

show_help() {
  cat << 'EOF'
Ralph Wiggum: The Loop (CLI Mode)

Usage:
  ./ralph-loop.sh [options] [workspace]

Options:
  -a, --agent AGENT      Agent to use: cursor, claude-code, gemini-cli, copilot-cli
                         (default: cursor, or first available)
  -n, --iterations N     Max iterations (default: 20)
  -m, --model MODEL      Model to use (defaults based on selected agent)
  --branch NAME          Create and work on a new branch
  --pr                   Open PR when complete (requires --branch)
  -y, --yes              Skip confirmation prompt
  -h, --help             Show this help

Agents:
  cursor                 Cursor Agent (cursor-agent CLI)
  claude-code            Anthropic Claude Code (claude CLI)
  gemini-cli             Google Gemini CLI (gemini CLI)
  copilot-cli            GitHub Copilot CLI (copilot CLI)

Examples:
  ./ralph-loop.sh                                    # Use default agent
  ./ralph-loop.sh -a claude-code                     # Use Claude Code
  ./ralph-loop.sh -a gemini-cli -m gemini-2.5-pro    # Use Gemini with specific model
  ./ralph-loop.sh -n 50                              # 50 iterations max
  ./ralph-loop.sh --branch feature/api --pr -y      # Scripted PR workflow

Environment:
  RALPH_AGENT            Override default agent (same as -a flag)
  RALPH_MODEL            Override default model (same as -m flag)

For interactive setup with a beautiful UI, use ralph-setup.sh instead.
EOF
}

# Parse command line arguments
WORKSPACE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--agent)
      RALPH_AGENT="$2"
      shift 2
      ;;
    -n|--iterations)
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    -m|--model)
      MODEL="$2"
      shift 2
      ;;
    --branch)
      USE_BRANCH="$2"
      shift 2
      ;;
    --pr)
      OPEN_PR=true
      shift
      ;;
    -y|--yes)
      SKIP_CONFIRM=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Use -h for help."
      exit 1
      ;;
    *)
      # Positional argument = workspace
      WORKSPACE="$1"
      shift
      ;;
  esac
done

# If no agent specified and model not specified, load default model for agent
if [[ -z "$MODEL" ]]; then
  load_selected_agent
  MODEL=$(agent_default_model)
fi

# =============================================================================
# MAIN
# =============================================================================

main() {
  # Resolve workspace
  if [[ -z "$WORKSPACE" ]]; then
    WORKSPACE="$(pwd)"
  elif [[ "$WORKSPACE" == "." ]]; then
    WORKSPACE="$(pwd)"
  else
    WORKSPACE="$(cd "$WORKSPACE" && pwd)"
  fi
  
  local task_file="$WORKSPACE/RALPH_TASK.md"
  
  # Show banner
  show_banner
  
  # Check prerequisites
  if ! check_prerequisites "$WORKSPACE"; then
    exit 1
  fi
  
  # Validate: PR requires branch
  if [[ "$OPEN_PR" == "true" ]] && [[ -z "$USE_BRANCH" ]]; then
    echo "❌ --pr requires --branch"
    echo "   Example: ./ralph-loop.sh --branch feature/foo --pr"
    exit 1
  fi
  
  # Initialize .ralph directory
  init_ralph_dir "$WORKSPACE"
  
  echo "Workspace: $WORKSPACE"
  echo "Task:      $task_file"
  echo ""
  
  # Show task summary
  echo "📋 Task Summary:"
  echo "─────────────────────────────────────────────────────────────────"
  head -30 "$task_file"
  echo "─────────────────────────────────────────────────────────────────"
  echo ""
  
  # Count criteria
  local total_criteria done_criteria remaining
  # Only count actual checkbox list items (- [ ], * [x], 1. [ ], etc.)
  total_criteria=$(grep -cE '^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]+\[(x| )\]' "$task_file" 2>/dev/null) || total_criteria=0
  done_criteria=$(grep -cE '^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]+\[x\]' "$task_file" 2>/dev/null) || done_criteria=0
  remaining=$((total_criteria - done_criteria))
  
  # Load agent for display
  load_selected_agent
  local agent_display_name
  agent_display_name=$(agent_name)

  echo "Progress: $done_criteria / $total_criteria criteria complete ($remaining remaining)"
  echo "Agent:    $agent_display_name ($RALPH_AGENT)"
  echo "Model:    $MODEL"
  echo "Max iter: $MAX_ITERATIONS"
  [[ -n "$USE_BRANCH" ]] && echo "Branch:   $USE_BRANCH"
  [[ "$OPEN_PR" == "true" ]] && echo "Open PR:  Yes"
  echo ""

  if [[ "$remaining" -eq 0 ]] && [[ "$total_criteria" -gt 0 ]]; then
    echo "🎉 Task already complete! All criteria are checked."
    exit 0
  fi

  # Confirm before starting (unless -y flag)
  if [[ "$SKIP_CONFIRM" != "true" ]]; then
    echo "This will run $agent_display_name locally to work on this task."
    echo "The agent will be rotated when context fills up (~80k tokens)."
    echo ""
    echo "Tip: Use ralph-setup.sh for interactive agent/model/option selection."
    echo "     Use -y flag to skip this prompt."
    echo ""
    read -p "Start Ralph loop? [y/N] " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 0
    fi
  fi
  
  # Run the loop
  run_ralph_loop "$WORKSPACE" "$SCRIPT_DIR"
  exit $?
}

main
