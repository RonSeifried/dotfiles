#!/usr/bin/env bash
# Ask AI - Rofi interface for Gemini API
set -euo pipefail

# Load environment variables
ENV_FILE="$HOME/.askai-env"
if [[ ! -f "$ENV_FILE" ]]; then
    notify-send "Ask AI" "Missing config file: $ENV_FILE\nCopy from .askai-env.example" -u critical
    exit 1
fi
# Extract key without sourcing arbitrary code
GEMINI_API_KEY=$(grep -E '^(export )?GEMINI_API_KEY=' "$ENV_FILE" \
    | head -1 | sed "s/^[^=]*=//; s/^['\"]//; s/['\"]$//")

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    notify-send "Ask AI" "GEMINI_API_KEY not set in $ENV_FILE" -u critical
    exit 1
fi

# Get user input from rofi
content=$(echo "" | rofi -dmenu -config ~/.config/rofi/ai.rasi -p ">" \
    -theme-str 'window { width: 40em; } listview { lines: 0; } entry { placeholder: "Ask AI..."; }')

# Make sure content is not empty
if [[ -z "$content" ]]; then
    exit 0
fi

# Prepare response file
RESP_FILE="/tmp/askai-resp.md"
rm -f "$RESP_FILE"

# Start Response Display in kitty
kitty --detach --class "askai" --override="font_size=14" ~/.config/scripts/rofi/ai/display-resp.sh &

# Send request to Gemini API
response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
    -H 'Content-Type: application/json' \
    -H "X-goog-api-key: $GEMINI_API_KEY" \
    -X POST \
    -d "{
        \"contents\": [
            {
                \"parts\": [
                    {
                        \"text\": $(printf '%s' "$content" | jq -Rs .)
                    }
                ]
            }
        ]
    }")

# Check for errors in response
if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
    error_msg=$(echo "$response" | jq -r '.error.message // "Unknown error"')
    printf '# Error\n\n%s\n' "$error_msg" > "$RESP_FILE"
    notify-send "Ask AI" "API Error: $error_msg" -u critical
    exit 1
fi

# Extract the AI response from the JSON output
ai_response=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // "No response received"')

# Write response to file
echo "$ai_response" > "$RESP_FILE"
