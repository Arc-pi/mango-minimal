#!/bin/bash
# Fixed Hybrid Wallpaper Switcher (awww + mpvpaper)

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
THUMB_DIR="$HOME/.cache/wallpaper-thumbs"
MONITOR="DP-1"   # CHANGE THIS to your monitor name (run: wlr-randr)

mkdir -p "$THUMB_DIR"

# Thumbnails
find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.mkv" \) | while read -r img; do
    thumb="$THUMB_DIR/$(basename "$img").png"
    [ -f "$thumb" ] || convert "$img[0]" -resize 290x -quality 90 "$thumb" 2>/dev/null || true
done &

selected=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.mkv" \) | sort | while read -r file; do
    name=$(basename "$file")
    thumb="$THUMB_DIR/$name.png"
    [ -f "$thumb" ] && echo -en "$name\0icon\x1f$thumb\n" || echo "$name"
done | rofi -dmenu \
    -i -show-icons \
    -p "󰸉  Wallpaper" \
    -theme-str 'window { width: 64%; location: center; }' \
    -theme-str 'listview { columns: 5; lines: 1; spacing: 14px; }' \
    -theme-str 'element { orientation: vertical; padding: 8px; }' \
    -theme-str 'element-icon { size: 235px; }' \
    -theme-str 'element-text { horizontal-align: 0.5; }')

if [ -n "$selected" ]; then
    fullpath="$WALLPAPER_DIR/$selected"
    echo "DEBUG: Selected $fullpath"
    
    pkill mpvpaper 2>/dev/null
    pkill -f "awww img" 2>/dev/null
    
    if [[ "$fullpath" == *.mp4 || "$fullpath" == *.mkv ]]; then
        echo "DEBUG: mpvpaper on $MONITOR"
        mpvpaper -o "loop" "$MONITOR" "$fullpath" &
    else
        echo "DEBUG: awww"
        awww img "$fullpath" --transition-type wipe --transition-angle 30 --transition-duration 1.2
    fi
    echo "✓ Wallpaper set: $selected"
fi
