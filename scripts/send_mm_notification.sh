#!/bin/bash
set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

ROOT_DIR="/root/spttx"
CONFIG_FILE="$ROOT_DIR/.env"

if [[ -f "$CONFIG_FILE" ]]; then
    set -a
    source "$CONFIG_FILE"
    set +a
fi

MM_API_URL="${MM_API_URL:?MM_API_URL is not configured}"
MM_API_TOKEN="${MM_API_TOKEN:?MM_API_TOKEN is not configured}"
MM_BOT_USER_ID="${MM_BOT_USER_ID:?MM_BOT_USER_ID is not configured}"

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <username> <message>" >&2
    exit 1
fi

USERNAME="$1"
MESSAGE="$2"

encode_array() {
    python3 - "$1" <<'PY'
import json, sys
print(json.dumps([sys.argv[1]]))
PY
}

encode_direct_payload() {
    python3 - "$1" "$2" <<'PY'
import json, sys
bot_user = sys.argv[1]
user_id = sys.argv[2]
print(json.dumps([bot_user, user_id]))
PY
}

encode_post_payload() {
    python3 - "$1" "$2" <<'PY'
import json, sys
channel_id = sys.argv[1]
message = sys.argv[2]
print(json.dumps({"channel_id": channel_id, "message": message}))
PY
}

parse_user_id() {
    python3 - "$1" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    if isinstance(data, list) and data:
        print(data[0].get("id", ""))
except Exception:
    pass
PY
}

parse_channel_id() {
    python3 - "$1" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    if isinstance(data, dict):
        print(data.get("id", ""))
except Exception:
    pass
PY
}


tmp_user=$(mktemp)
tmp_channel=$(mktemp)
tmp_post=$(mktemp)
trap 'rm -f "$tmp_user" "$tmp_channel" "$tmp_post"' EXIT

user_payload=$(encode_array "$USERNAME")
http_code=$(curl -s -w '%{http_code}' -o "$tmp_user" \
    -X POST -H "Authorization: Bearer $MM_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$user_payload" \
    "$MM_API_URL/users/usernames")

if [[ "$http_code" != "200" ]]; then
    echo "❌ Mattermost lookup failed (HTTP $http_code)" >&2
    cat "$tmp_user" >&2
    exit 1
fi

USER_ID=$(parse_user_id "$tmp_user")
if [[ -z "$USER_ID" ]]; then
    echo "❌ User $USERNAME not found in Mattermost" >&2
    exit 1
fi

echo "✓ Found user: $USERNAME -> $USER_ID"

channel_payload=$(encode_direct_payload "$MM_BOT_USER_ID" "$USER_ID")
http_code=$(curl -s -w '%{http_code}' -o "$tmp_channel" \
    -X POST -H "Authorization: Bearer $MM_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$channel_payload" \
    "$MM_API_URL/channels/direct")

if [[ "$http_code" != "201" && "$http_code" != "200" ]]; then
    echo "❌ Failed to create direct channel (HTTP $http_code)" >&2
    cat "$tmp_channel" >&2
    exit 1
fi

CHANNEL_ID=$(parse_channel_id "$tmp_channel")
if [[ -z "$CHANNEL_ID" ]]; then
    echo "❌ Failed to parse direct channel id" >&2
    exit 1
fi

echo "✓ Channel created: $CHANNEL_ID"

post_payload=$(encode_post_payload "$CHANNEL_ID" "$MESSAGE")
http_code=$(curl -s -w '%{http_code}' -o "$tmp_post" \
    -X POST -H "Authorization: Bearer $MM_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$post_payload" \
    "$MM_API_URL/posts")

if [[ "$http_code" != "201" && "$http_code" != "200" ]]; then
    echo "❌ Failed to send message (HTTP $http_code)" >&2
    cat "$tmp_post" >&2
    exit 1
fi

echo "✅ Message sent to @$USERNAME"
