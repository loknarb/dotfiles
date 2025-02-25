#!/usr/bin/env bash

# Function to convert short extensions to full patterns
expand_extensions() {
    for ext in "$@"; do
        case "$ext" in
            "ts") echo "ts|tsx";;
            "js") echo "js|jsx";;
            "md") echo "md|mdx";;
            "java") echo "java|class";;
            *) echo "$ext";;
        esac
    done
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [-s] [-a] [extension1] [extension2] ..."
    echo "Options:"
    echo "  -s    Interactive search mode (default: filename only)"
    echo "  -a    Show all files (including gitignored)"
    echo "Examples:"
    echo "  $0                            # search non-gitignored files"
    echo "  $0 -a                         # search all files"
    echo "  $0 ts md js java              # search specific types"
    echo "  $0 -s -a ts js                # search all files of type"
    exit 1
}

# Parse options
SEARCH_MODE=false
SHOW_ALL=false
while getopts "sha" opt; do
    case $opt in
        s) SEARCH_MODE=true;;
        a) SHOW_ALL=true;;
        h) show_usage;;
        \?) show_usage;;
    esac
done
shift $((OPTIND-1))

# Check for extensions and set pattern
if [ $# -eq 0 ]; then
    pattern=".*"
else
    pattern=$(expand_extensions "$@" | paste -sd"|" -)
fi

# Set ripgrep base options
RG_BASE_OPTS="--no-heading --color=never"  # Changed to --color=never to avoid color codes
if [ "$SHOW_ALL" = true ]; then
    RG_BASE_OPTS="$RG_BASE_OPTS --no-ignore --hidden"
fi

# Export current directory as environment variable for subshells
export SCRIPT_CURRENT_DIR="$(pwd)"

# Ensure correct path handling
search_and_preview_file() {
    local file="$1"
    local line="${2:-1}"
    
    # Strip any ANSI color codes that might be present
    file=$(echo "$file" | sed 's/\x1b\[[0-9;]*m//g')
    
    # Check if file exists directly
    if [[ -f "$file" ]]; then
        bat --style=numbers --color=always ${line:+--highlight-line "$line"} "$file"
        return 0
    fi
    
    # Check if file exists relative to current directory
    if [[ -f "$SCRIPT_CURRENT_DIR/$file" ]]; then
        bat --style=numbers --color=always ${line:+--highlight-line "$line"} "$SCRIPT_CURRENT_DIR/$file"
        return 0
    fi
    
    # Try to find the file by basename
    local basename_file=$(basename "$file")
    local found_file=$(find "$SCRIPT_CURRENT_DIR" -type f -name "$basename_file" | head -1)
    
    if [[ -n "$found_file" ]]; then
        bat --style=numbers --color=always ${line:+--highlight-line "$line"} "$found_file"
        return 0
    fi
    
    # As a last resort, try to find any file in a directory with a matching path
    local dir_path=$(dirname "$file")
    if [[ "$dir_path" != "." ]]; then
        local dir_name=$(basename "$dir_path")
        local potential_dirs=$(find "$SCRIPT_CURRENT_DIR" -type d -name "$dir_name" | head -1)
        
        if [[ -n "$potential_dirs" ]]; then
            local potential_file="$potential_dirs/$basename_file"
            if [[ -f "$potential_file" ]]; then
                bat --style=numbers --color=always ${line:+--highlight-line "$line"} "$potential_file"
                return 0
            fi
        fi
    fi
    
    echo "File not found: $file"
    echo "Tried:"
    echo "  $file"
    echo "  $SCRIPT_CURRENT_DIR/$file"
    echo "  Files named '$basename_file' in $SCRIPT_CURRENT_DIR"
    echo "  Files named '$basename_file' in directories named '$(basename "$dir_path")'"
    return 1
}

# Export the function for fzf to use
export -f search_and_preview_file

if [ "$SEARCH_MODE" = true ]; then
    # Interactive content search mode
    rg --line-number \
       $RG_BASE_OPTS \
       --path-separator / \
       --smart-case "" ${pattern:+--type-add "custom:*.{$(echo $pattern | tr '|' ',')}" --type custom} |
    fzf --delimiter : \
        --preview 'search_and_preview_file {1} {2}' \
        --preview-window='right:60%' \
        --bind 'ctrl-/:change-preview-window(down|hidden|)' \
        --bind 'change:reload:
            rg --line-number '"$RG_BASE_OPTS"' --path-separator / --smart-case {q} '"${pattern:+--type-add 'custom:*.{$(echo $pattern | tr '|' ',')}' --type custom}"' || true' \
        --disabled \
        --query "" \
        --header 'Type to fuzzy-search file contents. Press CTRL-/ to toggle preview.'
else
    # Original filename search mode
    rg --files $RG_BASE_OPTS --path-separator / | ([ "$pattern" != ".*" ] && rg "\.($pattern)$" || cat) | \
        fzf --multi \
            --preview 'search_and_preview_file {}' \
            --preview-window='right:60%' \
            --bind 'ctrl-/:change-preview-window(down|hidden|)'
fi