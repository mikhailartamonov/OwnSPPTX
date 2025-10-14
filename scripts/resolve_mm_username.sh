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

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <owncloud_username>" >&2
    exit 1
fi

OWNCLOUD_USER="$1"

encode_array() {
    python3 - "$1" <<'PY'
import json, sys
print(json.dumps([sys.argv[1]]))
PY
}

encode_search_payload() {
    python3 - "$1" <<'PY'
import json, sys
print(json.dumps({"term": sys.argv[1]}))
PY
}

call_api() {
    local method="$1"
    local endpoint="$2"
    local payload="$3"
    local tmp
    tmp=$(mktemp)
    local http_code
    if [[ -n "$payload" ]]; then
        http_code=$(curl -s -w '%{http_code}' -o "$tmp" \
            -X "$method" -H "Authorization: Bearer $MM_API_TOKEN" \
            -H "Content-Type: application/json" -d "$payload" \
            "$MM_API_URL$endpoint")
    else
        http_code=$(curl -s -w '%{http_code}' -o "$tmp" \
            -X "$method" -H "Authorization: Bearer $MM_API_TOKEN" \
            "$MM_API_URL$endpoint")
    fi
    if [[ "$http_code" != "200" ]]; then
        rm -f "$tmp"
        return 1
    fi
    cat "$tmp"
    rm -f "$tmp"
    return 0
}

parse_username_from_list() {
    python3 - "$1" <<'PY'
import json, sys
try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(1)
if isinstance(data, list):
    for item in data:
        username = item.get("username")
        if username:
            print(username)
            sys.exit(0)
sys.exit(1)
PY
}

parse_username_by_email() {
    python3 - "$1" "$2" <<'PY'
import json, sys
email = sys.argv[1]
try:
    data = json.loads(sys.argv[2])
except Exception:
    sys.exit(1)
if isinstance(data, list):
    for item in data:
        if item.get("email") == email and item.get("username"):
            print(item["username"])
            sys.exit(0)
sys.exit(1)
PY
}

# Try 1: direct username match
payload=$(encode_array "$OWNCLOUD_USER")
if response=$(call_api POST "/users/usernames" "$payload"); then
    if username=$(parse_username_from_list "$response" 2>/dev/null); then
        echo "$username"
        exit 0
    fi
fi

# Try 2: term search
payload=$(encode_search_payload "$OWNCLOUD_USER")
if response=$(call_api POST "/users/search" "$payload"); then
    if username=$(parse_username_from_list "$response" 2>/dev/null); then
        echo "$username"
        exit 0
    fi
fi

# Fetch bulk users once for email matching
if response=$(call_api GET "/users?per_page=500" ""); then
    email1="${OWNCLOUD_USER}@edutech-group.ru"
    if username=$(parse_username_by_email "$email1" "$response" 2>/dev/null); then
        echo "$username"
        exit 0
    fi
    email2="${OWNCLOUD_USER}@uchi-uchi.ru"
    if username=$(parse_username_by_email "$email2" "$response" 2>/dev/null); then
        echo "$username"
        exit 0
    fi
fi

exit 1
