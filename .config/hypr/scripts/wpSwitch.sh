WALLPAPER_DIR="$HOME/Pictures/Wallpapers/"
WALLPAPER_STATE="$HOME/.cache/current_wallpaper.txt"
HYPRPANEL_CONFIG="/$HOME/.config/hyprpanel/config.json"

pgrep -x swww-daemon > /dev/null || swww-daemon &
mapfile -t wallpapers < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | sort)

[ ${#wallpapers[@]} -eq 0 ] && echo "Wallpapers not found" && exit 1

current=""
[ -f "$WALLPAPER_STATE" ] && current=$(cat "$WALLPAPER_STATE")
index=0
for i in "${!wallpapers[@]}"; do
    [[ "${wallpapers[$i]}" == "$current" ]] && index=$i && break
done

next_index=$(( (index + 1) % ${#wallpapers[@]} ))
next_wallpaper="${wallpapers[$next_index]}"

swww img "$next_wallpaper" --transition-type any --transition-step 90

matugen image "$next_wallpaper"

if [ -f "$HYPRPANEL_CONFIG" ]; then
    jq --arg wp "$next_wallpaper" '.["wallpaper.image"] = $wp' "$HYPRPANEL_CONFIG" > "$HYPRPANEL_CONFIG.tmp" && mv "$HYPRPANEL_CONFIG.tmp" "$HYPRPANEL_CONFIG"
else
    echo "Hyprpanel Config not found"
fi

echo "$next_wallpaper" > "$WALLPAPER_STATE"

hyprpanel q; hyprpanel

exit 0
