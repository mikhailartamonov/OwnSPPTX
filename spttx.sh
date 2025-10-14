#!/bin/bash
set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

ROOT_DIR="/root/spttx"
cd "$ROOT_DIR"

LOG_FILE="$ROOT_DIR/def_logs"
LOCK_FILE="/var/lock/spttx.lock"
DATA_FILE="$ROOT_DIR/data"
CONFIG_FILE="$ROOT_DIR/.env"

mkdir -p "$(dirname "$LOCK_FILE")"
touch "$LOG_FILE"

log() {
    local level="$1"
    shift || true
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp][$level] $message" >> "$LOG_FILE"
}

info() {
    log INFO "$*"
    echo "$*"
}

warn() {
    log WARN "$*"
    echo "$*" >&2
}

error() {
    log ERROR "$*"
    echo "$*" >&2
}

fail() {
    local message="$1"
    local code="${2:-1}"
    error "$message"
    exit "$code"
}

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    warn "Another spttx instance is running. Exiting."
    exit 0
fi

if [[ -f "$CONFIG_FILE" ]]; then
    set -a
    source "$CONFIG_FILE"
    set +a
fi

if [[ ! -f "$DATA_FILE" ]]; then
    fail "Configuration file $DATA_FILE not found"
fi

sed -i 's/[[:blank:]]*$//' "$DATA_FILE"

default_lang=$(awk '$1=="languageCode"{print $2}' "$DATA_FILE")
profanity_filter=$(awk '$1=="profanityFilter"{print $2}' "$DATA_FILE")
raw_results=$(awk '$1=="rawResults"{print $2}' "$DATA_FILE")
defer_time_unit=$(awk '$1=="def_t"{print $2}' "$DATA_FILE")
defer_time_value=$(awk '$1=="def_l"{print $2}' "$DATA_FILE")
data_key=$(awk '$1=="key"{print $2}' "$DATA_FILE")
data_bucket=$(awk '$1=="cloud"{print $2}' "$DATA_FILE")

API_KEY="${YANDEX_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
    if [[ -n "${data_key:-}" && "$data_key" != "__ENV__" ]]; then
        API_KEY="$data_key"
    else
        fail "YANDEX_API_KEY is not configured. Set it in $CONFIG_FILE"
    fi
fi

S3_BUCKET="${S3_BUCKET:-}"
if [[ -z "$S3_BUCKET" ]]; then
    if [[ -n "${data_bucket:-}" && "$data_bucket" != "__ENV__" ]]; then
        S3_BUCKET="$data_bucket"
    else
        fail "S3_BUCKET is not configured. Set it in $CONFIG_FILE"
    fi
fi

S3_ENDPOINT="${S3_ENDPOINT:-https://storage.yandexcloud.net}"

determine_language() {
    local manual_lang="$1"
    case "$manual_lang" in
        de) echo "de-DE" ;;
        en) echo "en-US" ;;
        es) echo "es-ES" ;;
        fi) echo "fi-FI" ;;
        fr) echo "fr-FR" ;;
        it) echo "it-IT" ;;
        kk) echo "kk-KK" ;;
        nl) echo "nl-NL" ;;
        pl) echo "pl-PL" ;;
        pt) echo "pt-PT" ;;
        ru) echo "ru-RU" ;;
        sv) echo "sv-SE" ;;
        tr) echo "tr-TR" ;;
        auto) echo "auto" ;;
        *) echo "${default_lang:-ru-RU}" ;;
    esac
}

sanitize_filename() {
    local original="$1"
    echo "$original" | sed -E 's/\[\[.*\]\]//g; s/[ !@\$%&()\[\]]+/_/g; s/_{2,}/_/g; s/^_|_$//g'
}

process_file() {
    local source_path="$1"
    local directory
    directory=$(dirname "$source_path")/
    local file
    file=$(basename "$source_path")
    local manual_lang=""

    if [[ "$file" =~ \[\[([a-z]{2})\]\] ]]; then
        manual_lang="${BASH_REMATCH[1]}"
    fi

    local selected_lang
    selected_lang=$(determine_language "${manual_lang:-}")

    local model="deferred-general"
    [[ -n "$manual_lang" && "$manual_lang" != "auto" ]] && model="general"

    local file_clean
    file_clean=$(sanitize_filename "$file")
    local newfile
    newfile="${file_clean%.*}[[${manual_lang:-auto}]].${file##*.}"
    local target_path="${directory}${newfile}"

    if [[ "$source_path" != "$target_path" ]]; then
        mv "$source_path" "$target_path"
    fi

    local fownuser
    fownuser=$(echo "$target_path" | cut -d '/' -f 6)
    local fownusermail="${fownuser}@edutech-group.ru"

    mkdir -p "${directory}processed" "${directory}text"

    chmod 775 "$target_path"

    info "Обрабатываю файл: $target_path"

    local ffprobe_output
    if ! ffprobe_output=$(ffprobe -hide_banner "$target_path" 2>&1); then
        fail "ffprobe failed for $target_path"
    fi

    echo "$ffprobe_output" | grep -E 'Duration|Stream'

    local duration_human
    duration_human=$(echo "$ffprobe_output" | sed -n 's/^ *Duration: \([^,]*\),.*/\1/p' | head -n1)
    if [[ -z "$duration_human" ]]; then
        fail "Unable to parse duration for $target_path"
    fi

    IFS=: read -r dur_h dur_m dur_s <<< "$duration_human"
    dur_h=${dur_h#0}
    dur_m=${dur_m#0}
    local seconds
    seconds=$(printf '%.0f' "$(bc -l <<< "${dur_h:-0}*3600 + ${dur_m:-0}*60 + ${dur_s:-0}")")

    local price_rate="0.0025"
    [[ "$model" == "general" ]] && price_rate="0.01"
    local price
    price=$(printf '%.2f' "$(bc -l <<< "$price_rate * $seconds")")

    local opus_name
    opus_name="${file_clean}_$(date +'%d-%m-%Y')_out_mn.opus"

    if ! ffmpeg -hide_banner -loglevel error -i "$target_path" -ac 1 -c:a libopus "${directory}${opus_name}"; then
        fail "ffmpeg failed to convert $target_path"
    fi

    if ! aws --endpoint-url="$S3_ENDPOINT" s3 cp "${directory}${opus_name}" "s3://$S3_BUCKET/${opus_name}"; then
        fail "Failed to upload ${opus_name} to s3://$S3_BUCKET"
    fi

    cat > params.json <<EOF_JSON
{
  "config": {
    "specification": {
      "languageCode": "$selected_lang",
      "model": "$model",
      "profanityFilter": "$profanity_filter",
      "rawResults": "$raw_results"
    }
  },
  "audio": {"uri": "https://storage.yandexcloud.net/$S3_BUCKET/${opus_name}"}
}
EOF_JSON

    local response_file
    response_file=$(mktemp)
    local http_code
    http_code=$(curl -s -w '%{http_code}' -o "$response_file" \
        -X POST -H "Authorization: Api-Key $API_KEY" \
        -d '@params.json' \
        https://transcribe.api.cloud.yandex.net/speech/stt/v2/longRunningRecognize)

    if [[ "$http_code" != "200" ]]; then
        error "Failed to start transcription (HTTP $http_code): $(cat "$response_file")"
        rm -f "$response_file" "${directory}${opus_name}"
        fail "Stopping due to transcription API error"
    fi

    local id
    id=$(grep '"id"' "$response_file" | sed 's/^.*: "//; s/",*$//')
    rm -f "$response_file"

    if [[ -z "$id" ]]; then
        fail "Transcription ID not found in API response"
    fi

    mv "$target_path" "${directory}processed/"

    local def_name
    def_name="def_$(date +'%H%M_%d-%m-%Y').sh"
    cp deferred.sh "$def_name"
    sed -i "s|\$1|$id|" "$def_name"
    sed -i "s|\$2|${file_clean}|" "$def_name"
    sed -i "s|\$3|${opus_name}|" "$def_name"
    sed -i "s|\$4|$def_name|" "$def_name"
    sed -i "s|\$5|${defer_time_unit:-min}|" "$def_name"
    sed -i "s|\$6|${defer_time_value:-2}|" "$def_name"
    sed -i "s|\$7|$API_KEY|" "$def_name"
    sed -i "s|\$9|$fownuser|" "$def_name"
    sed -i "s|\$0|$fownusermail|" "$def_name"
    sed -i "s|\$8|${newfile}|" "$def_name"

    local checksum
    checksum=$(md5sum "${directory}processed/${newfile}" | awk '{print $1}')
    sed -i "s|\$aa|$checksum|" "$def_name"
    sed -i "s|\$bb|$S3_BUCKET|" "$def_name"
    sed -i "s|\$cc|$model|" "$def_name"
    sed -i "s|\$dd|$duration_human|" "$def_name"
    sed -i "s|\$ee|$seconds|" "$def_name"
    sed -i "s|\$ff|$price|" "$def_name"
    sed -i "s|\$gg|$directory|" "$def_name"

    chmod +x "$def_name"

    local path
    path=$(realpath "$def_name")
    "$path"

    rm -f "${directory}${opus_name}" params.json
    info "Задача отправлена: $id"
}

while true; do
    next_file=$(find /home/www/drive/data/*/files/audio2text/ -maxdepth 1 -type f ! -name '*.opus' -print -quit)
    if [[ -z "${next_file:-}" ]]; then
        info "Нет файлов для обработки 😊"
        break
    fi
    process_file "$next_file"
done
