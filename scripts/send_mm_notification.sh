#!/bin/bash

# Send Mattermost notification with optional file attachment
# Usage: send_mm_notification.sh <username> <message> [file_path]

ROOT_DIR="/home/www/drive/html/apps/audio2text/spttx_data"
CONFIG_FILE="$ROOT_DIR/.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE" >&2
    exit 1
fi

# Load config
source "$CONFIG_FILE"

MM_API_URL="${MM_API_URL:?MM_API_URL is not configured}"
MM_API_TOKEN="${MM_API_TOKEN:?MM_API_TOKEN is not configured}"
MM_BOT_USER_ID="${MM_BOT_USER_ID:?MM_BOT_USER_ID is not configured}"

USERNAME="$1"
MESSAGE="$2"
FILE_PATH="${3:-}"

if [ -z "$USERNAME" ] || [ -z "$MESSAGE" ]; then
    echo "Usage: $0 <username> <message> [file_path]" >&2
    exit 1
fi

# Function to create or get direct message channel
get_direct_channel() {
    local user1="$1"
    local user2="$2"

    local payload=$(cat <<EOF
["$user1", "$user2"]
EOF
)

    local response=$(curl -s -X POST \
        -H "Authorization: Bearer $MM_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$MM_API_URL/channels/direct")

    echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4
}

# Function to get user ID by username
get_user_id() {
    local username="$1"

    local response=$(curl -s -X GET \
        -H "Authorization: Bearer $MM_API_TOKEN" \
        "$MM_API_URL/users/username/$username")

    echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4
}

# Function to upload file to Mattermost
upload_file() {
    local file_path="$1"
    local channel_id="$2"

    if [ ! -f "$file_path" ]; then
        echo "ERROR: File not found: $file_path" >&2
        return 1
    fi

    local response=$(curl -s -X POST \
        -H "Authorization: Bearer $MM_API_TOKEN" \
        -F "files=@$file_path" \
        -F "channel_id=$channel_id" \
        "$MM_API_URL/files")

    # Extract file_id from response
    echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4
}

# Get user ID
USER_ID=$(get_user_id "$USERNAME")

if [ -z "$USER_ID" ]; then
    echo "ERROR: User not found: $USERNAME" >&2
    exit 1
fi

# Get or create direct channel
CHANNEL_ID=$(get_direct_channel "$MM_BOT_USER_ID" "$USER_ID")

if [ -z "$CHANNEL_ID" ]; then
    echo "ERROR: Failed to create/get direct channel" >&2
    exit 1
fi

# Upload file if provided
FILE_IDS=""
if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
    FILE_ID=$(upload_file "$FILE_PATH" "$CHANNEL_ID")
    if [ -n "$FILE_ID" ]; then
        FILE_IDS="\"$FILE_ID\""
        echo "File uploaded successfully: $FILE_ID"
    else
        echo "WARNING: Failed to upload file" >&2
    fi
fi

# Escape message for JSON
MESSAGE_ESCAPED=$(echo "$MESSAGE" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Create post payload
if [ -n "$FILE_IDS" ]; then
    POST_PAYLOAD=$(cat <<EOF
{
    "channel_id": "$CHANNEL_ID",
    "message": "$MESSAGE_ESCAPED",
    "file_ids": [$FILE_IDS]
}
EOF
)
else
    POST_PAYLOAD=$(cat <<EOF
{
    "channel_id": "$CHANNEL_ID",
    "message": "$MESSAGE_ESCAPED"
}
EOF
)
fi

# Send message
RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $MM_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$POST_PAYLOAD" \
    "$MM_API_URL/posts")

# Check if post was created successfully
if echo "$RESPONSE" | grep -q '"id"'; then
    echo "Mattermost notification sent successfully to @$USERNAME"
    exit 0
else
    echo "ERROR: Failed to send message. Response: $RESPONSE" >&2
    exit 1
fi
