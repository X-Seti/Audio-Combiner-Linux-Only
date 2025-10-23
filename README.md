# X-Seti - Oct 22 2025 - Audio Combiner 1.4 for Plasma 6 + PipeWire

Combine audio output to play through multiple HDMI monitors or audio devices simultaneously.

## 🎯 What This Does

This script allows you to output audio to **multiple devices at once** - perfect for:
- Playing sound through 2 HDMI monitors simultaneously
- Outputting to both headphones and speakers
- Any scenario where you want duplicate audio on multiple outputs

## 📋 Requirements

- Plasma 6
- PipeWire (with PulseAudio compatibility layer)
- `pactl` command (usually pre-installed)
- `notify-send` (optional, for notifications)

## 🚀 Installation

```bash
chmod +x install-simple.sh
./install-simple.sh
```

## 💡 Usage

### Command Line

```bash
# Toggle on/off
audio-combiner.sh toggle

# Enable combining
audio-combiner.sh start

# Disable combining
audio-combiner.sh stop

# Check status
audio-combiner.sh status
```

### Add Keyboard Shortcut (Recommended!)

1. Open **System Settings** → **Shortcuts** → **Custom Shortcuts**
2. Click **Edit** → **New** → **Global Shortcut** → **Command/URL**
3. Name it: "Toggle Audio Combiner"
4. Trigger: Press your desired key combo (e.g., `Meta+Shift+A`)
5. Action: `/usr/local/bin/audio-combiner.sh toggle`
6. Click **Apply**

Now you can toggle combined audio with one keypress!

### Add to Panel (Alternative)

1. Right-click panel → **Add Widgets**
2. Search for **Application Launcher** or **Icon-only Task Manager**
3. Add the "Toggle Audio Combiner" application

## 🎨 The Linked Icon

The `audio-link-symbolic.svg` icon shows two speakers linked together. You can use this as:
- Custom icon for panel launchers
- Keyboard shortcut indicator
- Desktop shortcut icon

## 🔧 How It Works

When enabled:
1. Creates a virtual "Combined Audio Output" sink
2. Uses `module-loopback` to duplicate audio to all physical outputs
3. Automatically detects HDMI and analog outputs
4. Sets the combined sink as your default output

When disabled:
- Removes all loopback modules
- Deletes the virtual sink
- Restores normal audio routing

## 🐛 Troubleshooting

**No audio after enabling:**
```bash
# Check if combined sink exists
pactl list short sinks | grep combined

# Check PipeWire status
systemctl --user status pipewire pipewire-pulse
```

**Audio latency/echo:**
The loopback modules might introduce slight latency. If problematic, adjust in:
```bash
# Edit the script and add latency parameters
pactl load-module module-loopback latency_msec=1 ...
```

**Only one device playing:**
```bash
# Check available sinks
pactl list short sinks

# Make sure your HDMI outputs are not suspended
pactl set-sink-port <sink-name> <hdmi-port>
```

**Script not found after install:**
Make sure `/usr/local/bin` is in your PATH:
```bash
echo $PATH | grep /usr/local/bin
```

## 📝 Files Included

- `audio-combiner.sh` - Main script
- `audio-link-symbolic.svg` - Linked speakers icon
- `audio-combiner.desktop` - Desktop entry for launchers
- `install-simple.sh` - Installation script
- `README.md` - This file

## 🔄 Automatic Startup (Optional)

To enable audio combining automatically on login:

1. Open **System Settings** → **Autostart**
2. Click **Add** → **Add Application**
3. Choose "Toggle Audio Combiner"

Or create a systemd user service (advanced).

## ❌ Uninstall

```bash
sudo rm /usr/local/bin/audio-combiner.sh
rm ~/.local/share/applications/audio-combiner.desktop
rm ~/.local/share/icons/hicolor/scalable/apps/audio-link-symbolic.svg
rm ~/.local/state/audio-combiner-active
```

## 🎓 Technical Details

The script uses PulseAudio compatibility layer commands (`pactl`) which work with PipeWire. It:
- Identifies all HDMI and analog stereo outputs
- Creates a null sink as the combination point
- Routes the null sink's monitor to each physical output
- Maintains state in `~/.local/state/audio-combiner-active`

## 📜 License

GPL-2.0+

---

**Note:** Since the Plasma volume popup UI is compiled into C++, this script-based approach provides the same functionality without needing to modify system files or recompile packages.
