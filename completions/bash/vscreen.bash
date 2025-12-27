#!/bin/bash
# ============================
# vscreen bash completion
# ============================
# Installation:
#   1. Copy to /etc/bash_completion.d/vscreen
#   OR
#   2. Source in ~/.bashrc: source /path/to/vscreen-completion.bash
# ============================

_vscreen() {
  local cur prev opts resolutions orientations outputs listmodes virtuals
  local i action

  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  # Main options
  opts="
    -r --resolution --size
    --output -c --change 
    --off --off-all
    --purge --purge-all
    --list
    -o --orientation
    --right-of --left-of --above --below --pos
    --no-auto --dry-run --debug 
    --help --version
  "

  # Resolution IDs and names
  resolutions="1 2 3 4 5 6 FHD HD+ HD HD10 HD+10 SD"
  
  # Orientation options
  orientations="L PR PL LF normal right left inverted"
  
  # List modes
  listmodes="all active free"

  # Get all connected outputs from xrandr (dynamic)
  outputs=$(xrandr 2>/dev/null | awk '/ connected/{print $1}')
  
  # Get virtual outputs dynamically
  virtuals=$(xrandr 2>/dev/null | awk '/^VIRTUAL[0-9]+/{print $1}' | sed 's/VIRTUAL//')
  
  # Get active virtual outputs
  active_virtuals=$(xrandr 2>/dev/null | awk '/^VIRTUAL[0-9]+ connected/{print $1}' | sed 's/VIRTUAL//')
  
  # Get free virtual outputs
  free_virtuals=$(comm -23 \
    <(xrandr 2>/dev/null | awk '/^VIRTUAL[0-9]+/{print $1}' | sed 's/VIRTUAL//' | sort) \
    <(xrandr 2>/dev/null | awk '/^VIRTUAL[0-9]+ connected/{print $1}' | sed 's/VIRTUAL//' | sort))

  # Detect action from previous words
  action=""
  for ((i=1; i < COMP_CWORD; i++)); do
    case "${COMP_WORDS[i]}" in
      --output) action="output";;
      -c|--change) action="change";;
      --off) action="off";;
      --list) action="list";;
    esac
  done

  # Context-sensitive completions
  case "$prev" in
    -r|--resolution)
      COMPREPLY=( $(compgen -W "$resolutions" -- "$cur") )
      return 0
      ;;
      
    --size)
      # Suggest common formats
      COMPREPLY=( $(compgen -W "1920x1080 1600x900 1366x768 1280x800 1440x900 800x450" -- "$cur") )
      return 0
      ;;
      
    --output)
      # Suggest free virtual output numbers
      if [[ -n "$free_virtuals" ]]; then
        COMPREPLY=( $(compgen -W "$free_virtuals" -- "$cur") )
      else
        # If no free virtuals, suggest all virtual numbers
        COMPREPLY=( $(compgen -W "$virtuals" -- "$cur") )
      fi
      return 0
      ;;
      
    -c|--change)
      # Suggest active virtual output numbers
      if [[ -n "$active_virtuals" ]]; then
        COMPREPLY=( $(compgen -W "$active_virtuals" -- "$cur") )
      else
        COMPREPLY=()
      fi
      return 0
      ;;
      
    --off)
      # Suggest active virtual output numbers
      if [[ -n "$active_virtuals" ]]; then
        COMPREPLY=( $(compgen -W "$active_virtuals" -- "$cur") )
      else
        COMPREPLY=()
      fi
      return 0
      ;;

      --purge)
      # Suggest active virtual output numbers (same as --off)
      if [[ -n "$active_virtuals" ]]; then
        COMPREPLY=( $(compgen -W "$active_virtuals" -- "$cur") )
      else
        COMPREPLY=()
      fi
      return 0
      ;;
      
    -o|--orientation)
      COMPREPLY=( $(compgen -W "$orientations" -- "$cur") )
      return 0
      ;;
      
    --right-of|--left-of|--above|--below)
      # Suggest all connected outputs
      COMPREPLY=( $(compgen -W "$outputs" -- "$cur") )
      return 0
      ;;
      
    --pos)
      # Suggest common positions
      COMPREPLY=( $(compgen -W "0x0 1920x0 3840x0 0x1080" -- "$cur") )
      return 0
      ;;
      
    --list)
      COMPREPLY=( $(compgen -W "$listmodes" -- "$cur") )
      return 0
      ;;
  esac

  # Smart completion based on action context
  case "$action" in
    output)
      # After --output, suggest resolution-related options
      local output_opts="-r --resolution --size -o --orientation --right-of --left-of --above --below --pos --no-auto"
      COMPREPLY=( $(compgen -W "$output_opts" -- "$cur") )
      return 0
      ;;
      
    change)
      # After --change, suggest change-related options
      local change_opts="-r --resolution --size -o --orientation --right-of --left-of --above --below --pos --no-auto"
      COMPREPLY=( $(compgen -W "$change_opts" -- "$cur") )
      return 0
      ;;
      
    list)
      # After --list, only suggest list modes if not already provided
      if [[ "$cur" != -* ]]; then
        COMPREPLY=( $(compgen -W "$listmodes" -- "$cur") )
      fi
      return 0
      ;;
  esac

  # Default: suggest main options
  if [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
  else
    # If no dash, might be completing a number or value
    case "${COMP_WORDS[COMP_CWORD-1]}" in
      --output)
        COMPREPLY=( $(compgen -W "$free_virtuals" -- "$cur") )
        ;;
      -c|--change|--off)
        COMPREPLY=( $(compgen -W "$active_virtuals" -- "$cur") )
        ;;
      *)
        COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
        ;;
    esac
  fi

  return 0
}

# Register completion
complete -F _vscreen vscreen