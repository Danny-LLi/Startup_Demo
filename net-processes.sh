#!/bin/bash

indent=""  # 2 spaces for alignment in Conky
max_len=40   # max chars to display for cmdline

# helper function to truncate string to max_len with ellipsis if needed
truncate_str() {
    local str="$1"
    if (( ${#str} > max_len )); then
        echo "${str:0:max_len}..."
    else
        echo "$str"
    fi
}

print_help() {
    echo -e "\n${indent}Usage: $0 [OPTION]"
    echo -e "\n${indent}Options:"
    echo -e "${indent}  -p <pid1[,pid2 ...]>   Show full details for one or more PIDs (comma without a space)"
    echo -e "${indent}  -h, --help             Display this help message"
    echo -e "\n${indent}Without options, lists all active internet-connected PIDs with their executables, ports, and command used.\n"
    exit 0
}

show_brief_process_list() {
    local seen=()
    local lines=()

    while read -r pid portinfo rest; do
        port=$(echo "$portinfo" | awk -F':' '{print $NF}')
        state=$(echo "$rest" | grep -oP '\(\K[^)]+' || echo "UNKNOWN")

        # Use both pid+port as a unique key
        key="${pid}_${port}"
        if [[ " ${seen[*]} " == *"$key"* ]]; then
            continue
        fi

        # Try getting command line
        if [[ -r /proc/$pid/cmdline ]]; then
            cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
        fi

        # Fallback to ps if cmdline is empty
        if [[ -z "$cmdline" ]]; then
            cmdline=$(ps -p "$pid" -o args= 2>/dev/null)
        fi

        # Still empty? use executable path
        if [[ -z "$cmdline" ]]; then
            cmdline=$(readlink -f /proc/$pid/exe 2>/dev/null)
        fi

        # Extract up to 2 absolute paths or fallback to first word command name
        if [[ -n "$cmdline" ]]; then
            cmd_paths=$(echo "$cmdline" | awk '{for (i=1;i<=NF;i++) if ($i ~ /^\//) {printf "%s ", $i; if (i==2) break}}' | sed 's/ *$//')
            if [[ -n "$cmd_paths" ]]; then
                cmdline_short=$(truncate_str "$cmd_paths")
            else
                cmdline_short=$(truncate_str "$(echo $cmdline | awk '{print $1}')")
            fi
        else
            cmdline_short="N/A"
        fi

        lines+=("$state|$pid|$port|$cmdline_short")
        seen+=("$key")
    done < <(lsof -i -nP 2>/dev/null | awk 'NR>1 {print $2, $9, $10, $11, $12, $13, $14}')

    IFS=$'\n' sorted_lines=($(printf '%s\n' "${lines[@]}" | \
        awk -F'|' '{
            if ($1 == "SYN_SENT") priority = 0;
            else if ($1 == "LISTEN") priority = 1;
            else priority = 2;
            print priority "|" $0
        }' | sort -t'|' -k1,1n -k2 | cut -d'|' -f2-))

    for line in "${sorted_lines[@]}"; do
        IFS='|' read -r state pid port cmdline_short <<< "$line"
        printf "┌─ Port: %-1s PID: %-1s State: %s\n" "$port" "$pid" "$state"
        printf "└─ ➤ %s\n" "$cmdline_short"
    done
}


show_full_details() {
    for pid in "$@"; do
        exe=$(readlink -f /proc/$pid/exe 2>/dev/null)
        user=$(ps -o user= -p $pid 2>/dev/null)

        if [[ -r /proc/$pid/cmdline ]]; then
            cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
        fi

        # Fallback if empty
        if [[ -z "$cmdline" ]]; then
            cmdline=$(ps -p "$pid" -o args= 2>/dev/null)
        fi

        connection=$(lsof -i -nP -sTCP:ESTABLISHED -a -p "$pid" 2>/dev/null | awk 'NR>1 {print $9}' | paste -sd ', ')

        if [[ -n "$exe" || -n "$cmdline" ]]; then
            cmdline_short=$(truncate_str "$cmdline")

            echo "${indent}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "${indent}🔢 PID:        $pid"
            echo "${indent}👤 User:       $user"
            echo "${indent}📎 Executable: $exe"
            echo "${indent}📝 Cmd Line:   $cmdline_short"
            echo "${indent}🌐 Connected to: ${connection:-N/A}"
        fi
    done
}

# Parse arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    print_help
elif [[ "$1" == "-p" && -n "$2" ]]; then
    clean_pids=$(echo "$2" | tr ',' ' ')
    read -r -a pid_array <<< "$clean_pids"
    show_full_details "${pid_array[@]}"
else
    show_brief_process_list
fi
d