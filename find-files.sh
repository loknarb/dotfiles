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
    echo "Usage: $0 [-s] [-a] [-e pattern1,pattern2,...] [extension1] [extension2] ..."
    echo "Options:"
    echo "  -s    Interactive search mode (default: filename only)"
    echo "  -a    Show all files (including gitignored)"
    echo "  -e    Exclude patterns (comma separated, e.g., '.test.,stories.')"
    echo "Examples:"
    echo "  $0                            # search non-gitignored files"
    echo "  $0 -a                         # search all files"
    echo "  $0 ts md js java              # search specific types"
    echo "  $0 -s -a ts js                # search all files of type"
    echo "  $0 -e .test.,.stories. ts js  # exclude test and stories files"
    exit 1
}

# Parse options
SEARCH_MODE=false
SHOW_ALL=false
EXCLUDE_PATTERN=""
while getopts "shae:" opt; do
    case $opt in
        s) SEARCH_MODE=true;;
        a) SHOW_ALL=true;;
        e) EXCLUDE_PATTERN="$OPTARG";;
        h) show_usage;;
        \?) show_usage;;
    esac
done
shift $((OPTIND-1))

# Process exclude patterns
EXCLUDE_RG_OPTS=""
if [ -n "$EXCLUDE_PATTERN" ]; then
    # Convert comma-separated patterns to individual --glob=!*pattern* arguments
    IFS=',' read -ra EXCLUDE_PATTERNS <<< "$EXCLUDE_PATTERN"
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        EXCLUDE_RG_OPTS="$EXCLUDE_RG_OPTS --glob=!*$pattern*"
    done
fi

# Check for extensions and set pattern
if [ $# -eq 0 ]; then
    pattern=".*"
else
    pattern=$(expand_extensions "$@" | paste -sd"|" -)
fi

# Set ripgrep base options
RG_BASE_OPTS="--no-heading --color=never $EXCLUDE_RG_OPTS"  # Added exclude options
if [ "$SHOW_ALL" = true ]; then
    RG_BASE_OPTS="$RG_BASE_OPTS --no-ignore --hidden"
fi

# Export current directory as environment variable for subshells
export SCRIPT_CURRENT_DIR="$(pwd)"

# Create a temporary script with the preview functions
PREVIEW_SCRIPT=$(mktemp)
cat << 'EOF' > "$PREVIEW_SCRIPT"
#!/usr/bin/env bash

resolve_file_path() {
    local file="$1"
    local current_dir="$2"
    
    # Strip any ANSI color codes that might be present
    file=$(echo "$file" | sed 's/\x1b\[[0-9;]*m//g')
    
    # Check if file exists directly
    if [[ -f "$file" ]]; then
        echo "$file"
        return 0
    fi
    
    # Check if file exists relative to current directory
    if [[ -f "$current_dir/$file" ]]; then
        echo "$current_dir/$file"
        return 0
    fi
    
    # Try to find the file by basename
    local basename_file=$(basename "$file")
    local found_file=$(find "$current_dir" -type f -name "$basename_file" | head -1)
    
    if [[ -n "$found_file" ]]; then
        echo "$found_file"
        return 0
    fi
    
    echo ""
    return 1
}

preview_file() {
    local file="$1"
    local line="${2:-1}"
    local current_dir="$3"
    
    local resolved_path=$(resolve_file_path "$file" "$current_dir")
    
    if [[ -n "$resolved_path" ]]; then
        bat --style=numbers --color=always ${line:+--highlight-line "$line"} "$resolved_path"
        return 0
    else
        echo "File not found: $file"
        return 1
    fi
}

# Call the preview function with all arguments
preview_file "$1" "$2" "$3"
EOF

chmod +x "$PREVIEW_SCRIPT"

# Modify the fzf commands to use the temporary preview script
if [ "$SEARCH_MODE" = true ]; then
    rg --line-number \
       $RG_BASE_OPTS \
       --path-separator / \
       --smart-case "" ${pattern:+--type-add "custom:*.{$(echo $pattern | tr '|' ',')}" --type custom} |
    fzf --delimiter : \
        --preview "$PREVIEW_SCRIPT {1} {2} $PWD" \
        --preview-window='right:60%' \
        --bind 'ctrl-/:change-preview-window(down|hidden|)' \
        --bind "enter:execute(code -g {1}:{2})" \
        --bind 'change:reload:
            rg --line-number '"$RG_BASE_OPTS"' --path-separator / --smart-case {q} '"${pattern:+--type-add 'custom:*.{$(echo $pattern | tr '|' ',')}' --type custom}"' || true' \
        --disabled \
        --query "" \
        --header 'Type to fuzzy-search file contents. Press CTRL-/ to toggle preview. Enter to open in VS Code.'
else
    rg --files $RG_BASE_OPTS --path-separator / | ([ "$pattern" != ".*" ] && rg "\.($pattern)$" || cat) | \
        fzf --multi \
            --preview "$PREVIEW_SCRIPT {} \"\" $PWD" \
            --preview-window='right:60%' \
            --bind 'ctrl-/:change-preview-window(down|hidden|)' \
            --bind "enter:execute(code {})" \
            --header 'Select file to open in VS Code. Press CTRL-/ to toggle preview.'
fi

# Clean up the temporary script
rm -f "$PREVIEW_SCRIPT"