#!/usr/bin/env bash
# Display AI response in terminal
# Waits for response file and renders it

RESP_FILE="/tmp/askai-resp.md"

# Clear screen and show waiting message
clear
echo -e "\033[1;34m󰧑 AI is thinking...\033[0m"
echo ""

# Wait until the response file appears and has content (max 60s)
timeout=200
elapsed=0
while [[ ! -s "$RESP_FILE" ]] && (( elapsed < timeout )); do
    sleep 0.3
    ((elapsed++))
done

if [[ ! -s "$RESP_FILE" ]]; then
    echo -e "\033[1;31mError: No response received (timeout)\033[0m"
    echo ""
    read -n 1 -s -r -p "Press any key to close..."
    exit 1
fi

clear

# Render markdown - try glow first, then bat, then fallback to cat
if command -v glow &>/dev/null; then
    glow -p -w 100 "$RESP_FILE"
elif command -v bat &>/dev/null; then
    bat --style=plain --language=markdown "$RESP_FILE"
else
    # Simple fallback: just cat with some basic formatting
    cat "$RESP_FILE"
fi

echo ""
echo -e "\033[2m─────────────────────────────────────\033[0m"
echo ""
read -n 1 -s -r -p "Press any key to close..."
