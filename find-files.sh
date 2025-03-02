#!/usr/bin/env bash

# Function to show usage
show_usage() {
    echo "Usage: $0 [-a] [-d pattern1,pattern2,...] [-e pattern1,pattern2,...] [-s extension1,extension2, ...]"
    echo "Options:"
    echo "  -s    Interactive search mode (default: filename only)"
    echo "  -a    Show all files (including gitignored)"
    echo "  -e    Exclude patterns (comma separated, e.g., 'test,stories')"
    echo "  -d    Directory glob patterns (comma separated, e.g., '**/src/**,**/lib/**')"
    echo "Examples:"
    echo "  ff                            # search non-gitignored files"
    echo "  ff -a                         # search all files"
    echo "  ff ts md js java              # search specific types"
    echo "  ff -s -a ts,js                # search all files of type"
    echo "  ff -e test,stories ts,js      # exclude test and stories files"
    exit 1
}

array_join() {
    if [[ $# -gt 0 ]]; then
        for arg in "$@"; do
            printf "'%s' " "${arg}"
        done
    fi
}

# ---------- execute immediately ----------
# Code below gets executed as soon as this script is sourced. Think wisely!

# Initialize arrays
INCLUDE=()
EXCLUDE=()
TYPE_FILTER_ARR=()
USE_GITIGNORE_OPT=()

# Parse command line options
while getopts ":e:s:a:h" opt; do
  case $opt in
    e) IFS=',' read -ra EXCLUDE_PATTERNS <<< "$OPTARG"
       for pattern in "${EXCLUDE_PATTERNS[@]}"; do
         EXCLUDE+=("--glob" "'!*.$pattern.*'")
       done ;;
    s) IFS=',' read -ra TYPE_PATTERNS <<< "$OPTARG"
       for pattern in "${TYPE_PATTERNS[@]}"; do
         TYPE_FILTER_ARR+=("--type" "$pattern")
       done ;;
    a) USE_GITIGNORE_OPT=('--no-ignore') ;;
    h) show_usage;;
    \?) show_usage;;
  esac
done
# Shift to remove processed options
shift $((OPTIND-1))

# If we only have one directory to search, invoke commands relative to that directory
PATHS=("$@")
SINGLE_DIR_ROOT=''
if [ ${#PATHS[@]} -eq 1 ]; then
  SINGLE_DIR_ROOT=${PATHS[0]}
  PATHS=()
  cd "$SINGLE_DIR_ROOT" || exit
fi

# 1. Search for text in files using Ripgrep
# 2. Interactively restart Ripgrep with reload action
# 3. Open the file
RG_PREFIX=(rg 
    --column
    --hidden
    "${USE_GITIGNORE_OPT[@]}"
    --line-number
    --no-heading
    --color=always
    --smart-case
    --colors 'match:fg:green'
    --colors 'path:fg:white'
    --colors 'path:style:nobold'
    "${EXCLUDE[@]}"
    "${TYPE_FILTER_ARR[@]}"
    --glob "'!**/.git/'"
    $(array_join "${GLOBS[@]+"${GLOBS[@]}"}")
)
if [[ ${#TYPE_FILTER_ARR[@]} -gt 0 ]]; then
    RG_PREFIX+=("$(printf "%s " "${TYPE_FILTER_ARR[@]}")")
fi
RG_PREFIX+=(" 2> /dev/null")

PREVIEW_ENABLED=${FIND_WITHIN_FILES_PREVIEW_ENABLED:-1}
PREVIEW_COMMAND=${FIND_WITHIN_FILES_PREVIEW_COMMAND:-'bat --decorations=always --color=always {1} --highlight-line {2} --style=header,grid'}
PREVIEW_WINDOW=${FIND_WITHIN_FILES_PREVIEW_WINDOW_CONFIG:-'right:border-left:50%:+{2}+3/3:~3'}
HAS_SELECTION=${HAS_SELECTION:-}
RESUME_SEARCH=${RESUME_SEARCH:-}
FUZZ_RG_QUERY=${FUZZ_RG_QUERY:-}
# We match against the beginning of the line so everything matches but nothing gets highlighted...
QUERY='^'
INITIAL_QUERY=''  # Don't show initial "^" regex in fzf
INITIAL_POS='1'
if [[ "$RESUME_SEARCH" -eq 1 ]]; then
    # ... or we resume the last search if that is desired
    if [[ -f "$LAST_QUERY_FILE" ]]; then
        QUERY="$(tail -n 1 "$LAST_QUERY_FILE")"
        INITIAL_QUERY="$QUERY"  # Do show the initial query when it's not "^"
        if [[ -f "$LAST_POS_FILE" ]]; then
            read -r pos < "$LAST_POS_FILE"
            ((pos++)) # convert index to position
            INITIAL_POS="$pos"
        fi
    fi
elif [[ "$HAS_SELECTION" -eq 1 ]]; then
    # ... or against the selection if we have one
    QUERY="$(cat "$SELECTION_FILE")"
    INITIAL_QUERY="$QUERY"  # Do show the initial query when it's not "^"
fi

# Some backwards compatibility stuff
if [[ $FZF_VER_PT1 == "0.2" && $FZF_VER_PT2 -lt 7 ]]; then
    if [[ "$PREVIEW_COMMAND" != "$FIND_WITHIN_FILES_PREVIEW_COMMAND" ]]; then
        PREVIEW_COMMAND='bat {1} --color=always --highlight-line {2} --line-range {2}:'
    fi
    if [[ "$PREVIEW_WINDOW" != "$FIND_WITHIN_FILES_PREVIEW_WINDOW_CONFIG" ]]; then
        PREVIEW_WINDOW='right:50%'
    fi
fi

PREVIEW_STR=()
if [[ "$PREVIEW_ENABLED" -eq 1 ]]; then
    PREVIEW_STR=(--preview "$PREVIEW_COMMAND" --preview-window "$PREVIEW_WINDOW")
fi

# dummy fallback binding because fzf v<0.36 does not support `load` and I did not figure out how to
# conditionally set the entire binding string (i.e., with the "--bind" part)
RESUME_POS_BINDING="backward-eof:ignore"
if [[ "$(printf '%s\n' "$FZF_VER_NUM" "0.36" | sort -V | head -n 1)" == "0.36" ]]; then
    # fzf version is greater or equal 0.36, so the `load` trigger is supported
    RESUME_POS_BINDING="load:pos($INITIAL_POS)"
fi

RG_QUERY_PARSING="{q}"
if [[ "$FUZZ_RG_QUERY" -eq 1 ]]; then
    RG_QUERY_PARSING="\$(echo {q} | sed 's/ /.*/g')"
    QUERY="$(echo $QUERY | sed 's/ /.*/g')"
fi

RG_PREFIX_STR=$(array_join "${RG_PREFIX+"${RG_PREFIX[@]}"}")
RG_PREFIX_STR="${RG_PREFIX+"${RG_PREFIX[@]}"}"
FZF_CMD="${RG_PREFIX+"${RG_PREFIX[@]}"} '$QUERY' $(array_join "${PATHS[@]+"${PATHS[@]}"}")"

# echo $FZF_CMD
# exit 1
# IFS sets the delimiter
# -r: raw
# -a: array
# Quick note on ${PREVIEW_STR[@]+"${PREVIEW_STR[@]}"}: Don't ask.
# https://stackoverflow.com/q/7577052/888916
IFS=: read -ra VAL < <(
  FZF_DEFAULT_COMMAND="$FZF_CMD" \
  fzf --ansi \
      --cycle \
      --bind 'ctrl-/:change-preview-window(down|hidden|)' \
      --bind "change:reload:$RG_PREFIX_STR $RG_QUERY_PARSING $(array_join "${PATHS[@]+"${PATHS[@]}"}") || true" \
      --bind 'enter:execute(code -g {1}: {2})' \
      --delimiter : \
      --disabled --query "$INITIAL_QUERY" \
      ${PREVIEW_STR[@]+"${PREVIEW_STR[@]}"}
      #--history "$LAST_QUERY_FILE" 
)