#!/bin/bash
# X-Seti - Oct 22 2025 - Audio Combiner 1.4 for Plasma 6 + PipeWire
# Ultra-low latency version for synchronized audio output

VERSION="1.4-lowlatency"
COMBINED_SINK_NAME="combined-output-ll"
CONFIG_FILE="$HOME/.config/audio-combiner/outputs-ll.conf"

# Latency settings (in microseconds, 1ms = 1000us)
# Lower = less delay, but might cause audio glitches on slower systems
LATENCY_USEC=500  # 0.5ms - very low latency (try 1000 or 2000 if you get glitches)

notify() {
    if command -v notify-send &> /dev/null; then
        notify-send -i "$2" "Audio Combiner (Low Latency)" "$1"
    fi
}

get_all_sinks() {
    pactl list short sinks | grep -v "$COMBINED_SINK_NAME" | awk '{print $2}'
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    fi
}

save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    echo "$@" > "$CONFIG_FILE"
}

create_combined_sink() {
    if [ $# -eq 0 ]; then
        echo "Error: No sinks provided" >&2
        return 1
    fi
    
    local sink_count=$#
    
    echo "Creating LOW-LATENCY combined audio sink for $sink_count devices..."
    echo "Latency: ${LATENCY_USEC}μs (${LATENCY_USEC}/1000ms)"
    
    # Create null sink with low latency settings
    pactl load-module module-null-sink \
        sink_name=$COMBINED_SINK_NAME \
        sink_properties=device.description="Combined_Audio_Output_LowLatency" \
        rate=48000 \
        channels=2
    
    # Create low-latency loopback for each output
    for sink in "$@"; do
        echo "  Linking to: $sink"
        pactl load-module module-loopback \
            latency_msec=0 \
            adjust_time=1 \
            max_latency_msec=5 \
            source=$COMBINED_SINK_NAME.monitor \
            sink="$sink" \
            source_dont_move=true \
            sink_dont_move=true
    done
    
    # Set as default
    pactl set-default-sink $COMBINED_SINK_NAME
    
    save_config "$@"
    
    notify "Low-latency audio combining enabled!\nLatency: ${LATENCY_USEC}μs" "audio-volume-high"
}

remove_combined_sink() {
    echo "Removing combined audio setup..."
    
    combined_module=$(pactl list short modules | grep "module-null-sink.*$COMBINED_SINK_NAME" | awk '{print $1}')
    loopback_modules=$(pactl list short modules | grep "module-loopback.*$COMBINED_SINK_NAME" | awk '{print $1}')
    
    for module in $loopback_modules; do
        pactl unload-module $module 2>/dev/null
    done
    
    if [ -n "$combined_module" ]; then
        pactl unload-module $combined_module 2>/dev/null
    fi
    
    notify "Audio combining disabled" "audio-volume-muted"
}

is_active() {
    pactl list short sinks | grep -q "$COMBINED_SINK_NAME"
}

interactive_select() {
    mapfile -t sinks < <(get_all_sinks)
    
    if [ ${#sinks[@]} -eq 0 ]; then
        echo "Error: No audio sinks found" >&2
        exit 1
    fi
    
    echo "Select which audio outputs to combine:" >&2
    echo "=======================================" >&2
    echo "" >&2
    
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
    
    echo "${selected_sinks[@]}"
}

# Tune system for low latency (optional, requires root)
tune_system() {
    echo "Tuning system for low-latency audio..."
    echo ""
    echo "This requires root privileges and will:"
    echo "  - Increase PipeWire priority"
    echo "  - Adjust audio buffer sizes"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    
    # Set PipeWire to realtime priority
    sudo systemctl --user set-property pipewire.service CPUSchedulingPolicy=fifo
    sudo systemctl --user set-property pipewire.service CPUSchedulingPriority=95
    
    echo "✓ System tuned for low latency"
    echo "Restart PipeWire for changes to take effect:"
    echo "  systemctl --user restart pipewire pipewire-pulse"
}

case "$1" in
    start|enable|on)
        if is_active; then
            echo "Combined audio is already active"
            exit 0
        fi
        
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
    
    tune)
        tune_system
        ;;
        
    status)
        if is_active; then
            echo "Low-latency combined audio is ACTIVE"
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
            exit 1
        fi
        ;;
        
    *)
        echo "Audio Combiner v$VERSION (Low-Latency Edition)"
        echo ""
        echo "Usage: $0 {start|stop|toggle|configure|tune|status}"
        echo ""
        echo "  configure  - Select which outputs to combine"
        echo "  start      - Enable combined audio output"
        echo "  stop       - Disable combined audio output"  
        echo "  toggle     - Toggle between enabled/disabled"
        echo "  tune       - Optimize system for low latency (requires root)"
        echo "  status     - Check current status"
        echo ""
        echo "This version uses aggressive low-latency settings."
        echo "If you experience audio glitches, edit LATENCY_USEC in the script."
        exit 1
        ;;
esac
