#!/bin/bash
# Ralph Wiggum: Stream Parser
#
# Parses stream-json output from various AI coding agents in real-time.
# Supports: Cursor Agent, Claude Code, Gemini CLI, GitHub Copilot CLI
#
# Tracks token usage, detects failures/gutter, writes to .ralph/ logs.
#
# Usage:
#   <agent-cli> --output-format stream-json "..." | ./stream-parser.sh /path/to/workspace
#
# Outputs to stdout:
#   - ROTATE when threshold hit (80k tokens)
#   - WARN when approaching limit (70k tokens)
#   - GUTTER when stuck pattern detected
#   - COMPLETE when agent outputs <ralph>COMPLETE</ralph>
#
# Writes to .ralph/:
#   - activity.log: all operations with context health
#   - errors.log: failures and gutter detection
#
# The parser is designed to be agent-agnostic and handles common stream-json formats.

set -euo pipefail

WORKSPACE="${1:-.}"
RALPH_DIR="$WORKSPACE/.ralph"

# Ensure .ralph directory exists
mkdir -p "$RALPH_DIR"

# Thresholds
WARN_THRESHOLD=70000
ROTATE_THRESHOLD=80000

# Tracking state
BYTES_READ=0
BYTES_WRITTEN=0
ASSISTANT_CHARS=0
SHELL_OUTPUT_CHARS=0
PROMPT_CHARS=0
TOOL_CALLS=0
WARN_SENT=0

# Estimate initial prompt size (Ralph prompt is ~2KB + file references)
PROMPT_CHARS=3000

# Gutter detection - use temp files instead of associative arrays (macOS bash 3.x compat)
FAILURES_FILE=$(mktemp)
WRITES_FILE=$(mktemp)
trap "rm -f $FAILURES_FILE $WRITES_FILE" EXIT

# Get context health emoji
get_health_emoji() {
  local tokens=$1
  local pct=$((tokens * 100 / ROTATE_THRESHOLD))
  
  if [[ $pct -lt 60 ]]; then
    echo "🟢"
  elif [[ $pct -lt 80 ]]; then
    echo "🟡"
  else
    echo "🔴"
  fi
}

calc_tokens() {
  local total_bytes=$((PROMPT_CHARS + BYTES_READ + BYTES_WRITTEN + ASSISTANT_CHARS + SHELL_OUTPUT_CHARS))
  echo $((total_bytes / 4))
}

# Log to activity.log
log_activity() {
  local message="$1"
  local timestamp=$(date '+%H:%M:%S')
  local tokens=$(calc_tokens)
  local emoji=$(get_health_emoji $tokens)
  
  echo "[$timestamp] $emoji $message" >> "$RALPH_DIR/activity.log"
}

# Log to errors.log
log_error() {
  local message="$1"
  local timestamp=$(date '+%H:%M:%S')
  
  echo "[$timestamp] $message" >> "$RALPH_DIR/errors.log"
}

# Check and log token status
log_token_status() {
  local tokens=$(calc_tokens)
  local pct=$((tokens * 100 / ROTATE_THRESHOLD))
  local emoji=$(get_health_emoji $tokens)
  local timestamp=$(date '+%H:%M:%S')
  
  local status_msg="TOKENS: $tokens / $ROTATE_THRESHOLD ($pct%)"
  
  if [[ $pct -ge 90 ]]; then
    status_msg="$status_msg - rotation imminent"
  elif [[ $pct -ge 72 ]]; then
    status_msg="$status_msg - approaching limit"
  fi
  
  local breakdown="[read:$((BYTES_READ/1024))KB write:$((BYTES_WRITTEN/1024))KB assist:$((ASSISTANT_CHARS/1024))KB shell:$((SHELL_OUTPUT_CHARS/1024))KB]"
  echo "[$timestamp] $emoji $status_msg $breakdown" >> "$RALPH_DIR/activity.log"
}

# Check for gutter conditions
check_gutter() {
  local tokens=$(calc_tokens)
  
  # Check rotation threshold
  if [[ $tokens -ge $ROTATE_THRESHOLD ]]; then
    log_activity "ROTATE: Token threshold reached ($tokens >= $ROTATE_THRESHOLD)"
    echo "ROTATE" 2>/dev/null || true
    return
  fi
  
  # Check warning threshold (only emit once per session)
  if [[ $tokens -ge $WARN_THRESHOLD ]] && [[ $WARN_SENT -eq 0 ]]; then
    log_activity "WARN: Approaching token limit ($tokens >= $WARN_THRESHOLD)"
    WARN_SENT=1
    echo "WARN" 2>/dev/null || true
  fi
}

# Track shell command failure
track_shell_failure() {
  local cmd="$1"
  local exit_code="$2"
  
  if [[ $exit_code -ne 0 ]]; then
    # Count failures for this command (grep -c exits 1 if no match, so use || true)
    local count
    count=$(grep -c "^${cmd}$" "$FAILURES_FILE" 2>/dev/null) || count=0
    count=$((count + 1))
    echo "$cmd" >> "$FAILURES_FILE"
    
    log_error "SHELL FAIL: $cmd → exit $exit_code (attempt $count)"
    
    if [[ $count -ge 3 ]]; then
      log_error "⚠️ GUTTER: same command failed ${count}x"
      echo "GUTTER" 2>/dev/null || true
    fi
  fi
}

# Track file writes for thrashing detection
track_file_write() {
  local path="$1"
  local now=$(date +%s)
  
  # Log write with timestamp
  echo "$now:$path" >> "$WRITES_FILE"
  
  # Count writes to this file in last 10 minutes
  local cutoff=$((now - 600))
  local count=$(awk -F: -v cutoff="$cutoff" -v path="$path" '
    $1 >= cutoff && $2 == path { count++ }
    END { print count+0 }
  ' "$WRITES_FILE")
  
  # Check for thrashing (5+ writes in 10 minutes)
  if [[ $count -ge 5 ]]; then
    log_error "⚠️ THRASHING: $path written ${count}x in 10 min"
    echo "GUTTER" 2>/dev/null || true
  fi
}

# Extract text content from various JSON formats (agent-agnostic)
extract_text_content() {
  local line="$1"

  # Try different content extraction patterns (supports multiple agents)
  local text=""

  # Pattern 1: Cursor-style .message.content[0].text
  text=$(echo "$line" | jq -r '.message.content[0].text // empty' 2>/dev/null) || true
  [[ -n "$text" ]] && echo "$text" && return

  # Pattern 2: Claude Code style .content[0].text
  text=$(echo "$line" | jq -r '.content[0].text // empty' 2>/dev/null) || true
  [[ -n "$text" ]] && echo "$text" && return

  # Pattern 3: Direct .text field
  text=$(echo "$line" | jq -r '.text // empty' 2>/dev/null) || true
  [[ -n "$text" ]] && echo "$text" && return

  # Pattern 4: .message.text
  text=$(echo "$line" | jq -r '.message.text // empty' 2>/dev/null) || true
  [[ -n "$text" ]] && echo "$text" && return

  echo ""
}

# Process a single JSON line from stream
process_line() {
  local line="$1"

  # Skip empty lines
  [[ -z "$line" ]] && return

  # Parse JSON type (supports various agent formats)
  local type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null) || return
  local subtype=$(echo "$line" | jq -r '.subtype // empty' 2>/dev/null) || true

  case "$type" in
    "system"|"init"|"start")
      local model=$(echo "$line" | jq -r '.model // .modelId // "unknown"' 2>/dev/null) || model="unknown"
      if [[ "$subtype" == "init" ]] || [[ "$type" == "init" ]] || [[ "$type" == "start" ]]; then
        log_activity "SESSION START: model=$model"
      fi
      ;;

    "assistant"|"message"|"text"|"content")
      # Track assistant message characters (agent-agnostic)
      local text
      text=$(extract_text_content "$line")
      if [[ -n "$text" ]]; then
        local chars=${#text}
        ASSISTANT_CHARS=$((ASSISTANT_CHARS + chars))

        # Check for completion sigil
        if [[ "$text" == *"<ralph>COMPLETE</ralph>"* ]]; then
          log_activity "✅ Agent signaled COMPLETE"
          echo "COMPLETE" 2>/dev/null || true
        fi

        # Check for gutter sigil
        if [[ "$text" == *"<ralph>GUTTER</ralph>"* ]]; then
          log_activity "🚨 Agent signaled GUTTER (stuck)"
          echo "GUTTER" 2>/dev/null || true
        fi
      fi
      ;;

    "tool_call"|"tool_use"|"tool")
      if [[ "$subtype" == "started" ]] || [[ "$subtype" == "start" ]]; then
        TOOL_CALLS=$((TOOL_CALLS + 1))

      elif [[ "$subtype" == "completed" ]] || [[ "$subtype" == "complete" ]] || [[ "$subtype" == "result" ]]; then
        # Handle read tool completion (supports multiple formats)
        local tool_name=$(echo "$line" | jq -r '.tool_call.name // .name // .tool // ""' 2>/dev/null) || tool_name=""

        if echo "$line" | jq -e '.tool_call.readToolCall.result.success // .result.success // false' > /dev/null 2>&1 || [[ "$tool_name" =~ [Rr]ead ]]; then
          local path=$(echo "$line" | jq -r '.tool_call.readToolCall.args.path // .args.path // .input.path // "unknown"' 2>/dev/null) || path="unknown"
          local lines=$(echo "$line" | jq -r '.tool_call.readToolCall.result.success.totalLines // .result.totalLines // .result.lines // 0' 2>/dev/null) || lines=0

          local content_size=$(echo "$line" | jq -r '.tool_call.readToolCall.result.success.contentSize // .result.contentSize // .result.size // 0' 2>/dev/null) || content_size=0
          local bytes
          if [[ $content_size -gt 0 ]]; then
            bytes=$content_size
          else
            bytes=$((lines * 100))  # ~100 chars/line for code
          fi
          BYTES_READ=$((BYTES_READ + bytes))

          local kb=$(echo "scale=1; $bytes / 1024" | bc 2>/dev/null || echo "$((bytes / 1024))")
          log_activity "READ $path ($lines lines, ~${kb}KB)"

        # Handle write tool completion (supports multiple formats)
        elif echo "$line" | jq -e '.tool_call.writeToolCall.result.success // false' > /dev/null 2>&1 || [[ "$tool_name" =~ [Ww]rite|[Ee]dit ]]; then
          local path=$(echo "$line" | jq -r '.tool_call.writeToolCall.args.path // .args.path // .input.path // "unknown"' 2>/dev/null) || path="unknown"
          local lines=$(echo "$line" | jq -r '.tool_call.writeToolCall.result.success.linesCreated // .result.linesCreated // .result.lines // 0' 2>/dev/null) || lines=0
          local bytes=$(echo "$line" | jq -r '.tool_call.writeToolCall.result.success.fileSize // .result.fileSize // .result.size // 0' 2>/dev/null) || bytes=0
          BYTES_WRITTEN=$((BYTES_WRITTEN + bytes))

          local kb=$(echo "scale=1; $bytes / 1024" | bc 2>/dev/null || echo "$((bytes / 1024))")
          log_activity "WRITE $path ($lines lines, ${kb}KB)"

          # Track for thrashing detection
          track_file_write "$path"

        # Handle shell/bash tool completion (supports multiple formats)
        elif echo "$line" | jq -e '.tool_call.shellToolCall.result // .tool_call.bashToolCall.result // false' > /dev/null 2>&1 || [[ "$tool_name" =~ [Ss]hell|[Bb]ash|[Cc]ommand ]]; then
          local cmd=$(echo "$line" | jq -r '.tool_call.shellToolCall.args.command // .tool_call.bashToolCall.args.command // .args.command // .input.command // "unknown"' 2>/dev/null) || cmd="unknown"
          local exit_code=$(echo "$line" | jq -r '.tool_call.shellToolCall.result.exitCode // .tool_call.bashToolCall.result.exitCode // .result.exitCode // .result.exit_code // 0' 2>/dev/null) || exit_code=0

          local stdout=$(echo "$line" | jq -r '.tool_call.shellToolCall.result.stdout // .tool_call.bashToolCall.result.stdout // .result.stdout // .result.output // ""' 2>/dev/null) || stdout=""
          local stderr=$(echo "$line" | jq -r '.tool_call.shellToolCall.result.stderr // .tool_call.bashToolCall.result.stderr // .result.stderr // ""' 2>/dev/null) || stderr=""
          local output_chars=$((${#stdout} + ${#stderr}))
          SHELL_OUTPUT_CHARS=$((SHELL_OUTPUT_CHARS + output_chars))

          if [[ $exit_code -eq 0 ]]; then
            if [[ $output_chars -gt 1024 ]]; then
              log_activity "SHELL $cmd → exit 0 (${output_chars} chars output)"
            else
              log_activity "SHELL $cmd → exit 0"
            fi
          else
            log_activity "SHELL $cmd → exit $exit_code"
            track_shell_failure "$cmd" "$exit_code"
          fi
        fi

        # Check thresholds after each tool call
        check_gutter
      fi
      ;;

    "result"|"end"|"done"|"complete")
      local duration=$(echo "$line" | jq -r '.duration_ms // .duration // .elapsed_ms // 0' 2>/dev/null) || duration=0
      local tokens=$(calc_tokens)
      log_activity "SESSION END: ${duration}ms, ~$tokens tokens used"
      ;;
  esac
}

# Main loop: read JSON lines from stdin
main() {
  # Initialize activity log for this session
  echo "" >> "$RALPH_DIR/activity.log"
  echo "═══════════════════════════════════════════════════════════════" >> "$RALPH_DIR/activity.log"
  echo "Ralph Session Started: $(date)" >> "$RALPH_DIR/activity.log"
  echo "═══════════════════════════════════════════════════════════════" >> "$RALPH_DIR/activity.log"
  
  # Track last token log time
  local last_token_log=$(date +%s)
  
  while IFS= read -r line; do
    process_line "$line"
    
    # Log token status every 30 seconds
    local now=$(date +%s)
    if [[ $((now - last_token_log)) -ge 30 ]]; then
      log_token_status
      last_token_log=$now
    fi
  done
  
  # Final token status
  log_token_status
}

main
