#!/bin/bash
# Ralph Wiggum: Interactive Setup & Loop
#
# THE main entry point for Ralph. Uses gum for a beautiful CLI experience,
# falls back to simple prompts if gum is not installed.
#
# Supports multiple AI agents:
#   - Cursor Agent (cursor-agent)
#   - Claude Code (claude)
#   - Gemini CLI (gemini)
#   - GitHub Copilot CLI (copilot)
#
# Usage:
#   ./ralph-setup.sh                    # Interactive setup + run loop
#   ./ralph-setup.sh /path/to/project   # Run in specific project
#
# Requirements:
#   - RALPH_TASK.md in the project root
#   - Git repository
#   - At least one supported agent CLI installed
#   - gum (optional, for enhanced UI): brew install gum

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "$SCRIPT_DIR/ralph-common.sh"

# =============================================================================
# GUM DETECTION
# =============================================================================

HAS_GUM=false
if command -v gum &> /dev/null; then
  HAS_GUM=true
fi

# =============================================================================
# GUM UI HELPERS
# =============================================================================

# Select agent using gum or fallback
select_agent() {
  # Get installed agents
  local installed_agents
  installed_agents=($(get_available_agents_for_ui))

  if [[ ${#installed_agents[@]} -eq 0 ]]; then
    echo "ERROR: No supported agents installed!" >&2
    echo "" >&2
    echo "Install at least one of these:" >&2
    echo "  • cursor-agent: curl https://cursor.com/install -fsS | bash" >&2
    echo "  • claude:       npm install -g @anthropic-ai/claude-code" >&2
    echo "  • codex:        npm install -g @openai/codex" >&2
    echo "  • gemini:       npm install -g @google/gemini-cli" >&2
    echo "  • copilot:      npm install -g @github/copilot" >&2
    exit 1
  fi

  # Build display names for UI
  local display_names=()
  for agent in "${installed_agents[@]}"; do
    display_names+=("$(get_agent_display_name "$agent")")
  done

  if [[ "$HAS_GUM" == "true" ]]; then
    local selected_display
    selected_display=$(gum choose --header "Select AI agent:" "${display_names[@]}")

    # Map display name back to agent ID
    local i=0
    for name in "${display_names[@]}"; do
      if [[ "$name" == "$selected_display" ]]; then
        echo "${installed_agents[$i]}"
        return
      fi
      ((i++))
    done
  else
    echo ""
    echo "Select AI agent:"
    local i=1
    for name in "${display_names[@]}"; do
      echo "  $i) $name"
      ((i++))
    done
    echo ""
    read -p "Choice [1]: " choice
    choice="${choice:-1}"

    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#installed_agents[@]} ]]; then
      echo "${installed_agents[$((choice-1))]}"
    else
      echo "${installed_agents[0]}"
    fi
  fi
}

# Get models for selected agent (dynamically loaded)
get_models_for_agent() {
  local agent="$1"
  RALPH_AGENT="$agent"
  load_selected_agent
  local models
  models=($(agent_get_models))
  # Add Custom option
  models+=("Custom...")
  echo "${models[@]}"
}

# Select model using gum or fallback
# Args: $1 = agent name (to get appropriate models)
select_model() {
  local agent="${1:-cursor}"

  # Get models for this agent
  local MODELS
  MODELS=($(get_models_for_agent "$agent"))

  # Get default model for this agent
  RALPH_AGENT="$agent"
  load_selected_agent
  local default_model
  default_model=$(agent_default_model)

  if [[ "$HAS_GUM" == "true" ]]; then
    local selected
    selected=$(gum choose --header "Select model:" "${MODELS[@]}")

    if [[ "$selected" == "Custom..." ]]; then
      selected=$(gum input --placeholder "Enter model name" --value "$default_model")
    fi
    echo "$selected"
  else
    echo ""
    echo "Select model:"
    local i=1
    for m in "${MODELS[@]}"; do
      if [[ "$m" == "Custom..." ]]; then
        echo "  $i) Custom (enter manually)"
      else
        echo "  $i) $m"
      fi
      ((i++))
    done
    echo ""
    read -p "Choice [1]: " choice
    choice="${choice:-1}"

    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#MODELS[@]} ]]; then
      local selected="${MODELS[$((choice-1))]}"
      if [[ "$selected" == "Custom..." ]]; then
        read -p "Enter model name: " selected
      fi
      echo "$selected"
    else
      echo "${MODELS[0]}"
    fi
  fi
}

# Get max iterations using gum or fallback
get_max_iterations() {
  if [[ "$HAS_GUM" == "true" ]]; then
    local value
    value=$(gum input --header "Max iterations:" --placeholder "20" --value "20")
    echo "${value:-20}"
  else
    read -p "Max iterations [20]: " value
    echo "${value:-20}"
  fi
}

# Multi-select options using gum or fallback
# Returns space-separated list of selected options
select_options() {
  local options=(
    "Commit to current branch"
    "Run single iteration first"
    "Work on new branch"
    "Open PR when complete"
  )
  
  if [[ "$HAS_GUM" == "true" ]]; then
    # gum choose --no-limit returns newline-separated selections
    local selected
    selected=$(gum choose --no-limit --header "Options (space to select, enter to confirm):" "${options[@]}") || true
    echo "$selected"
  else
    echo ""
    echo "Options (enter numbers separated by spaces, or press Enter to skip):"
    local i=1
    for opt in "${options[@]}"; do
      echo "  $i) $opt"
      ((i++))
    done
    echo ""
    read -p "Select options [none]: " choices
    
    local selected=""
    for choice in $choices; do
      if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#options[@]} ]]; then
        if [[ -n "$selected" ]]; then
          selected="$selected"$'\n'"${options[$((choice-1))]}"
        else
          selected="${options[$((choice-1))]}"
        fi
      fi
    done
    echo "$selected"
  fi
}

# Get branch name using gum or fallback
get_branch_name() {
  if [[ "$HAS_GUM" == "true" ]]; then
    gum input --header "Branch name:" --placeholder "feature/my-feature"
  else
    read -p "Branch name: " branch
    echo "$branch"
  fi
}

# Confirm action using gum or fallback
confirm_action() {
  local message="$1"
  
  if [[ "$HAS_GUM" == "true" ]]; then
    gum confirm "$message"
  else
    read -p "$message [y/N] " -n 1 -r
    echo ""
    [[ $REPLY =~ ^[Yy]$ ]]
  fi
}

# Show styled header
show_header() {
  local text="$1"
  if [[ "$HAS_GUM" == "true" ]]; then
    gum style --border double --padding "0 2" --border-foreground 212 "$text"
  else
    echo "═══════════════════════════════════════════════════════════════════"
    echo "$text"
    echo "═══════════════════════════════════════════════════════════════════"
  fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
  local workspace="${1:-.}"
  if [[ "$workspace" == "." ]]; then
    workspace="$(pwd)"
  fi
  workspace="$(cd "$workspace" && pwd)"
  
  local task_file="$workspace/RALPH_TASK.md"
  
  # Show banner
  echo ""
  show_header "🐛 Ralph Wiggum: Autonomous Development Loop"
  echo ""
  
  if [[ "$HAS_GUM" == "true" ]]; then
    echo "  Using gum for enhanced UI ✨"
  else
    echo "  💡 Install gum for a better experience: https://github.com/charmbracelet/gum#installation"
  fi
  echo ""
  
  # Check prerequisites
  if ! check_prerequisites "$workspace"; then
    exit 1
  fi
  
  # Initialize .ralph directory
  init_ralph_dir "$workspace"
  
  echo "Workspace: $workspace"
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
  
  echo "Progress: $done_criteria / $total_criteria criteria complete ($remaining remaining)"
  echo ""
  
  if [[ "$remaining" -eq 0 ]] && [[ "$total_criteria" -gt 0 ]]; then
    echo "🎉 Task already complete! All criteria are checked."
    exit 0
  fi
  
  # ==========================================================================
  # INTERACTIVE SETUP
  # ==========================================================================

  echo ""
  if [[ "$HAS_GUM" == "true" ]]; then
    gum style --foreground 212 "Configure your Ralph session:"
  else
    echo "Configure your Ralph session:"
  fi
  echo ""

  # 1. Select agent
  RALPH_AGENT=$(select_agent)
  load_selected_agent
  local agent_display_name
  agent_display_name=$(agent_name)
  echo "✓ Agent: $agent_display_name ($RALPH_AGENT)"

  # 2. Select model (based on selected agent)
  MODEL=$(select_model "$RALPH_AGENT")
  echo "✓ Model: $MODEL"

  # 3. Max iterations
  MAX_ITERATIONS=$(get_max_iterations)
  echo "✓ Max iterations: $MAX_ITERATIONS"

  # 4. Options
  local selected_options
  selected_options=$(select_options)
  
  # Parse selected options
  local run_single_first=false
  USE_BRANCH=""
  OPEN_PR=false
  
  while IFS= read -r opt; do
    case "$opt" in
      "Commit to current branch")
        echo "✓ Will commit to current branch"
        ;;
      "Run single iteration first")
        run_single_first=true
        echo "✓ Will run single iteration first"
        ;;
      "Work on new branch")
        USE_BRANCH=$(get_branch_name)
        echo "✓ Branch: $USE_BRANCH"
        ;;
      "Open PR when complete")
        OPEN_PR=true
        echo "✓ Will open PR when complete"
        ;;
    esac
  done <<< "$selected_options"
  
  # Validate: PR requires branch
  if [[ "$OPEN_PR" == "true" ]] && [[ -z "$USE_BRANCH" ]]; then
    echo ""
    echo "⚠️  Opening PR requires a branch. Please specify a branch name:"
    USE_BRANCH=$(get_branch_name)
    echo "✓ Branch: $USE_BRANCH"
  fi
  
  echo ""
  
  # ==========================================================================
  # CONFIRMATION
  # ==========================================================================
  
  echo "─────────────────────────────────────────────────────────────────"
  echo "Summary:"
  echo "  • Agent:      $agent_display_name"
  echo "  • Model:      $MODEL"
  echo "  • Iterations: $MAX_ITERATIONS max"
  [[ -n "$USE_BRANCH" ]] && echo "  • Branch:     $USE_BRANCH"
  [[ "$OPEN_PR" == "true" ]] && echo "  • Open PR:    Yes"
  [[ "$run_single_first" == "true" ]] && echo "  • Test first: Yes (single iteration)"
  echo "─────────────────────────────────────────────────────────────────"
  echo ""
  
  if ! confirm_action "Start Ralph loop?"; then
    echo "Aborted."
    exit 0
  fi
  
  # ==========================================================================
  # RUN LOOP
  # ==========================================================================
  
  # Export settings for the loop
  export RALPH_AGENT
  export MODEL
  export MAX_ITERATIONS
  export USE_BRANCH
  export OPEN_PR
  
  # Handle single iteration first
  if [[ "$run_single_first" == "true" ]]; then
    echo ""
    echo "🧪 Running single iteration first..."
    echo ""
    
    # Run just one iteration
    local signal
    signal=$(run_iteration "$workspace" "1" "" "$SCRIPT_DIR")
    
    # Check result
    local task_status
    task_status=$(check_task_complete "$workspace")
    
    if [[ "$task_status" == "COMPLETE" ]]; then
      echo ""
      echo "🎉 Task completed in single iteration!"
      exit 0
    fi
    
    echo ""
    echo "Single iteration complete. Review the changes."
    echo ""
    
    if ! confirm_action "Continue with full loop?"; then
      echo "Stopped after single iteration."
      exit 0
    fi
    
    # Continue with remaining iterations (start from 2)
    local iteration=2
    local session_id=""
    
    while [[ $iteration -le $MAX_ITERATIONS ]]; do
      signal=$(run_iteration "$workspace" "$iteration" "$session_id" "$SCRIPT_DIR")
      task_status=$(check_task_complete "$workspace")
      
      if [[ "$task_status" == "COMPLETE" ]]; then
        log_progress "$workspace" "**Session $iteration ended** - ✅ TASK COMPLETE"
        echo ""
        echo "═══════════════════════════════════════════════════════════════════"
        echo "🎉 RALPH COMPLETE! All criteria satisfied."
        echo "═══════════════════════════════════════════════════════════════════"
        echo ""
        echo "Completed in $iteration iteration(s)."
        
        # Open PR if requested
        if [[ "$OPEN_PR" == "true" ]] && [[ -n "$USE_BRANCH" ]]; then
          echo ""
          echo "📝 Opening pull request..."
          cd "$workspace"
          git push -u origin "$USE_BRANCH" 2>/dev/null || git push
          if command -v gh &> /dev/null; then
            gh pr create --fill || echo "⚠️  Could not create PR automatically."
          fi
        fi
        
        exit 0
      fi
      
      case "$signal" in
        "ROTATE")
          log_progress "$workspace" "**Session $iteration ended** - 🔄 Context rotation"
          echo "🔄 Rotating to fresh context..."
          iteration=$((iteration + 1))
          session_id=""
          ;;
        "GUTTER")
          log_progress "$workspace" "**Session $iteration ended** - 🚨 GUTTER"
          echo "🚨 Gutter detected. Check .ralph/errors.log"
          exit 1
          ;;
        *)
          if [[ "$task_status" == INCOMPLETE:* ]]; then
            iteration=$((iteration + 1))
          fi
          ;;
      esac
      
      sleep 2
    done
    
    echo "⚠️  Max iterations reached."
    exit 1
  fi
  
  # Run full loop directly
  run_ralph_loop "$workspace" "$SCRIPT_DIR"
  exit $?
}

main "$@"
