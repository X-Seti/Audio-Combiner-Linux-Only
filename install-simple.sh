#!/bin/bash
# X-Seti - Oct 22 2025 - Audio Combiner 1.4 for Plasma 6 + PipeWire

echo "Installing Audio Combiner..."

# Copy script to system
sudo cp audio-combiner.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/audio-combiner.sh

# Copy desktop file
mkdir -p ~/.local/share/applications
cp audio-combiner.desktop ~/.local/share/applications/

# Copy icon
cp audio-link-symbolic.svg ~/.local/share/icons/hicolor/scalable/apps/

echo ""
echo "✅ Installation complete!"
echo ""
echo "Usage:"
echo "  Toggle: /usr/local/bin/audio-combiner.sh toggle"
echo "  Start:  /usr/local/bin/audio-combiner.sh start"
echo "  Stop:   /usr/local/bin/audio-combiner.sh stop"
echo "  Status: /usr/local/bin/audio-combiner.sh status"
echo ""
echo "You can now:"
echo "1. Add a keyboard shortcut in System Settings → Shortcuts"
echo "   Command: /usr/local/bin/audio-combiner.sh toggle"
echo ""
echo "2. Right-click the desktop and add the 'Toggle Audio Combiner' launcher"
echo ""
echo "3. Add a custom button to your panel:"
echo "   Panel → Add Widgets → Icon-only Task Manager → Configure"
echo "   Or use the Application Launcher widget"
