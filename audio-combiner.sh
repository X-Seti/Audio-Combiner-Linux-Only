#!/bin/bash
# X-Seti - Oct 22 2025 - Audio Combiner 1.4 for Plasma 6 + PipeWire
# Allows you to select which specific outputs to combine

VERSION="1.4"
COMBINED_SINK_NAME="combined-output"
CONFIG_FILE="$HOME/.config/audio-combiner/outputs.conf"

# Function to send desktop notification
notify() {
    if command -v notify-send &> /dev/null; then
        notify-send -i "$2" "Audio Combiner" "$1"
    fi
}

# Function to get all available sinks (excluding our combined sink)
get_all_sinks() {
    pactl list short sinks | grep -v "$COMBINED_SINK_NAME" | awk '{print $2}'
}

# Function to load saved configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    fi
}

# Function to save configuration
save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    echo "$@" > "$CONFIG_FILE"
}

# Function to create combined sink with specific outputs
create_combined_sink() {
    if [ $# -eq 0 ]; then
        echo "Error: No sinks provided" >&2
        return 1
    fi
    
    local sink_count=$#
    
    echo "Creating combined audio sink for $sink_count devices..."
    
    # Create a null sink for combining
    pactl load-module module-null-sink sink_name=$COMBINED_SINK_NAME sink_properties=device.description="Combined_Audio_Output"
    
    # Create loopback for each selected output device
    for sink in "$@"; do
        echo "  Linking to: $sink"
        pactl load-module module-loopback latency_msec=1 adjust_time=0 source=$COMBINED_SINK_NAME.monitor sink="$sink"
    done
    
    # Set as default
    pactl set-default-sink $COMBINED_SINK_NAME
    
    # Save configuration
    save_config "$@"
    
    notify "Audio combining enabled!\nSound playing on $sink_count devices" "audio-volume-high"
}

# Function to remove combined sink
remove_combined_sink() {
    echo "Removing combined audio setup..."
    
    # Get the module IDs
    combined_module=$(pactl list short modules | grep "module-null-sink.*$COMBINED_SINK_NAME" | awk '{print $1}')
    loopback_modules=$(pactl list short modules | grep "module-loopback.*$COMBINED_SINK_NAME" | awk '{print $1}')
    
    # Unload loopbacks
    for module in $loopback_modules; do
        pactl unload-module $module 2>/dev/null
    done
    
    # Unload combined sink
    if [ -n "$combined_module" ]; then
        pactl unload-module $combined_module 2>/dev/null
    fi
    
    notify "Audio combining disabled" "audio-volume-muted"
}

# Check if currently active
is_active() {
    pactl list short sinks | grep -q "$COMBINED_SINK_NAME"
}

# Interactive sink selection
interactive_select() {
    # Get all sinks into an array
    mapfile -t sinks < <(get_all_sinks)
    
    if [ ${#sinks[@]} -eq 0 ]; then
        echo "Error: No audio sinks found" >&2
        exit 1
    fi
    
    echo "Select which audio outputs to combine:" >&2
    echo "=======================================" >&2
    echo "" >&2
    
    # Show numbered list with descriptions
    for i in "${!sinks[@]}"; do
        local sink="${sinks[$i]}"
        local desc=$(pactl list sinks | grep -A 20 "Name: $sink" | grep "Description:" | cut -d: -f2- | xargs)
        local state=$(pactl list sinks | grep -A 20 "Name: $sink" | grep "State:" | cut -d: -f2- | xargs)
        echo "[$((i+1))] $desc" >&2
        echo "    Name: $sink" >&2
        echo "    State: $state" >&2
        echo "" >&2
    done
    
    echo "Enter the numbers of outputs to combine (space-separated, e.g., '1 2'):" >&2
    read -r selection
    
    # Parse selection and build array of selected sinks
    selected_sinks=()
    for num in $selection; do
        index=$((num-1))
        if [ $index -ge 0 ] && [ $index -lt ${#sinks[@]} ]; then
            selected_sinks+=("${sinks[$index]}")
        fi
    done
    
    if [ ${#selected_sinks[@]} -eq 0 ]; then
        echo "Error: No valid sinks selected" >&2
        exit 1
    fi
    
    # Return the selected sinks (space-separated)
    echo "${selected_sinks[@]}"
}

# Main logic
case "$1" in
    start|enable|on)
        if is_active; then
            echo "Combined audio is already active"
            exit 0
        fi
        
        # Load saved config
        saved_config=$(load_config)
        if [ -n "$saved_config" ]; then
            echo "Using saved configuration..."
            create_combined_sink $saved_config
        else
            echo "No saved configuration found."
            echo "Please run '$0 configure' first to select outputs."
            exit 1
        fi
        ;;
        
    stop|disable|off)
        if ! is_active; then
            echo "Combined audio is already inactive"
            exit 0
        fi
        remove_combined_sink
        ;;
        
    toggle)
        if is_active; then
            remove_combined_sink
        else
            # Use saved config
            saved_config=$(load_config)
            if [ -n "$saved_config" ]; then
                create_combined_sink $saved_config
            else
                echo "No saved configuration. Run '$0 configure' first."
                exit 1
            fi
        fi
        ;;
        
    configure|config|setup)
        echo "Audio Combiner v$VERSION - Configuration"
        echo "Configuring audio outputs..."
        echo ""
        
        # Run interactive selection
        selected=$(interactive_select)
        
        if [ -n "$selected" ]; then
            save_config $selected
            echo ""
            echo "Configuration saved!"
            echo "Selected outputs:"
            for sink in $selected; do
                echo "  - $sink"
            done
            echo ""
            echo "Run '$0 start' or '$0 toggle' to enable."
        fi
        ;;
        
    list)
        echo "Available audio outputs:"
        echo "------------------------"
        get_all_sinks | while read -r sink; do
            desc=$(pactl list sinks | grep -A 20 "Name: $sink" | grep "Description:" | cut -d: -f2- | xargs)
            state=$(pactl list sinks | grep -A 20 "Name: $sink" | grep "State:" | cut -d: -f2- | xargs)
            echo "  Name: $sink"
            echo "  Description: $desc"
            echo "  State: $state"
            echo ""
        done
        ;;
        
    status)
        if is_active; then
            echo "Combined audio is ACTIVE"
            saved_config=$(load_config)
            if [ -n "$saved_config" ]; then
                count=$(echo "$saved_config" | wc -w)
                echo "Combining $count outputs:"
                for sink in $saved_config; do
                    echo "  - $sink"
                done
            fi
            exit 0
        else
            echo "Combined audio is INACTIVE"
            saved_config=$(load_config)
            if [ -n "$saved_config" ]; then
                echo ""
                echo "Saved configuration exists. Run '$0 toggle' to enable."
            else
                echo ""
                echo "No configuration found. Run '$0 configure' first."
            fi
            exit 1
        fi
        ;;
        
    *)
        echo "Audio Combiner v$VERSION"
        echo "Usage: $0 {start|stop|toggle|configure|list|status}"
        echo ""
        echo "  configure  - Select which outputs to combine (first time setup)"
        echo "  start      - Enable combined audio output"
        echo "  stop       - Disable combined audio output"  
        echo "  toggle     - Toggle between enabled/disabled"
        echo "  list       - List all available audio outputs"
        echo "  status     - Check current status"
        echo ""
        echo "Quick start:"
        echo "  1. $0 configure   (select outputs)"
        echo "  2. $0 toggle      (enable/disable)"
        exit 1
        ;;
esac
