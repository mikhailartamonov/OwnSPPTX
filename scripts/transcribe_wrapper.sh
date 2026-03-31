#!/bin/bash
set -euo pipefail

CONFIG_FILE="$1"

# Load config
source "$CONFIG_FILE"

# Set log and status files
TMP_DIR="/home/www/drive/data/audio2text_tmp"
LOG_FILE="${TMP_DIR}/audio2text_${TASK_ID}.log"
STATUS_FILE="${TMP_DIR}/audio2text_${TASK_ID}.status"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

set_status() {
    echo "$1" > "$STATUS_FILE"
    log "STATUS: $1"
}

fail() {
    log "ERROR: $1"
    set_status "Error: $1"
    exit 1
}

log "=== Audio2Text Transcription Started ==="
log "Task ID: $TASK_ID"
log "User ID: $USER_ID"
log "Filename: $FILENAME"
log "File path: $FILE_PATH"
log "Language: $LANGUAGE"
log "Model: $MODEL"
log "Engine: ${ENGINE:-yandex}"
log "Output directory: $OUTPUT_DIR"

set_status "Initializing..."

# Check file exists
if [ ! -f "$FILE_PATH" ]; then
    fail "File not found: $FILE_PATH"
fi

# Check if .opus file
if [[ "$FILENAME" == *.opus ]]; then
    fail "Cannot process .opus files (intermediate format)"
fi

log "File size: $(stat -c%s "$FILE_PATH" 2>/dev/null || stat -f%z "$FILE_PATH") bytes"
log "File type: $(file -b "$FILE_PATH")"

# ============================================================
# ENGINE BRANCHING: Whisper or Yandex SpeechKit
# ============================================================

if [ "${ENGINE:-yandex}" = "whisper" ]; then
    # ========================================
    # WHISPER (LOCAL) PATH
    # ========================================
    log "Using Whisper engine (local)"

    WHISPER_SCRIPT="/home/www/drive/html/apps/audio2text/scripts/whisper_transcribe.py"
    PYTHON="/opt/python3.9/bin/python3.9"

    if [ ! -f "$WHISPER_SCRIPT" ]; then
        fail "Whisper script not found: $WHISPER_SCRIPT"
    fi

    if [ ! -f "$PYTHON" ]; then
        fail "Python 3.9 not found: $PYTHON"
    fi

    # Run whisper transcription (it writes its own status updates)
    set_status "Loading Whisper model..."
    if ! nice -n 19 ionice -c 3 "$PYTHON" "$WHISPER_SCRIPT" "$CONFIG_FILE"; then
        # Check if status was already set by Python script
        CURRENT_STATUS=$(cat "$STATUS_FILE" 2>/dev/null || echo "")
        if [[ "$CURRENT_STATUS" != Error:* ]]; then
            fail "Whisper transcription failed"
        fi
        exit 1
    fi

    # Read result metadata from Python script
    META_FILE="${TMP_DIR}/audio2text_${TASK_ID}.meta"
    if [ -f "$META_FILE" ]; then
        source "$META_FILE"
        rm -f "$META_FILE"
    else
        log "WARN: Meta file not found, skipping notifications"
        exit 0
    fi

    # Get file info for notifications
    FILE_SIZE=$(du -h "$RESULT_PATH" 2>/dev/null | cut -f1)
    DURATION_SECONDS="${DURATION:-0}"
    MINUTES_TOTAL=$(printf '%.1f' "$(echo "$DURATION_SECONDS / 60" | bc -l 2>/dev/null || echo 0)")

    # Update ownCloud index
    OWNCLOUD_DIR="/home/www/drive/html"
    if [ -f "$OWNCLOUD_DIR/occ" ]; then
        php "$OWNCLOUD_DIR/occ" files:scan --path="/$USER_ID/files/$(basename "$(dirname "$RESULT_PATH")")" >> "$LOG_FILE" 2>&1 || log "WARN: Failed to scan ownCloud directory"
    fi

    log "COMPLETED: Whisper transcription finished successfully"
    log "Result file: $RESULT_NAME"
    set_status "completed"

    # Send notifications (same as Yandex path)
    RESOLVE_MM_SCRIPT="/home/www/drive/html/apps/audio2text/scripts/resolve_mm_username.sh"
    SEND_MM_SCRIPT="/home/www/drive/html/apps/audio2text/scripts/send_mm_notification.sh"
    SEND_EMAIL_SCRIPT="/home/www/drive/html/apps/audio2text/scripts/send_email_notification.sh"

    # Mattermost notification
    if [ -f "$RESOLVE_MM_SCRIPT" ] && [ -f "$SEND_MM_SCRIPT" ]; then
        log "Sending Mattermost notification..."
        MM_USERNAME=$("$RESOLVE_MM_SCRIPT" "$USER_ID" 2>/dev/null || true)

        if [ -n "$MM_USERNAME" ]; then
            OWNCLOUD_URL="https://drive.spbsot.ru"
            RESULT_FILE_URL="$OWNCLOUD_URL/index.php/apps/files/?dir=/&scrollto=$(echo "$RESULT_NAME" | sed 's/ /%20/g')"
            ORIGINAL_FILE_URL="$OWNCLOUD_URL/index.php/apps/files/?dir=/&scrollto=$(echo "$FILENAME" | sed 's/ /%20/g')"

            MM_MESSAGE="### :white_check_mark: Распознавание речи завершено (Whisper)

**Исходный файл:** \`$FILENAME\`
**Результат:** \`$RESULT_NAME\` (${FILE_SIZE})
**Движок:** Whisper (${WHISPER_MODEL:-small})
**Язык:** ${DETECTED_LANG:-auto}
**Длительность:** ${MINUTES_TOTAL} мин

:inbox_tray: **Файл с текстом прикреплён к сообщению**

---
:page_facing_up: [Открыть результат в ownCloud]($RESULT_FILE_URL)
:file_folder: [Открыть оригинал в ownCloud]($ORIGINAL_FILE_URL)

_Автоматическое уведомление от Audio2Text_"

            "$SEND_MM_SCRIPT" "$MM_USERNAME" "$MM_MESSAGE" "$RESULT_PATH" >> "$LOG_FILE" 2>&1 || log "WARN: Failed to send Mattermost notification"
            log "Mattermost notification sent to @$MM_USERNAME"
        fi
    fi

    # Email notification
    if [ -f "$SEND_EMAIL_SCRIPT" ]; then
        log "Sending email notification..."

        EMAIL_BODY="Добрый день!

Распознавание речи для файла '$FILENAME' успешно завершено.

Информация о результате:
  Файл результата: $RESULT_NAME
  Размер: ${FILE_SIZE}
  Движок: Whisper (${WHISPER_MODEL:-small})
  Язык: ${DETECTED_LANG:-auto}
  Длительность: ${MINUTES_TOTAL} мин

Ссылки для просмотра в ownCloud:
  Результат: https://drive.spbsot.ru/index.php/apps/files/?dir=/&scrollto=$RESULT_NAME
  Оригинал: https://drive.spbsot.ru/index.php/apps/files/?dir=/&scrollto=$FILENAME

С уважением,
Служба автоматического распознавания речи
ownCloud Audio2Text (Whisper)"

        "$SEND_EMAIL_SCRIPT" "${USER_ID}@edutech-group.ru" "Распознавание завершено (Whisper): $FILENAME" "$EMAIL_BODY" "$RESULT_PATH" >> "$LOG_FILE" 2>&1 || log "WARN: Failed to send email"
        log "Email notification sent"
    fi

    # Cleanup config
    rm -f "$CONFIG_FILE"
    exit 0
fi

# ========================================
# YANDEX SPEECHKIT PATH (existing logic)
# ========================================

# Get file info for pricing
set_status "Analyzing file..."
FFPROBE_OUTPUT=$(ffprobe -hide_banner "$FILE_PATH" 2>&1)
log "FFprobe output: $FFPROBE_OUTPUT"

DURATION_HUMAN=$(echo "$FFPROBE_OUTPUT" | sed -n 's/^ *Duration: \([^,]*\),.*/\1/p' | head -n1)
if [ -z "$DURATION_HUMAN" ]; then
    fail "Unable to parse duration"
fi

IFS=: read -r dur_h dur_m dur_s <<< "$DURATION_HUMAN"
dur_h=${dur_h#0}
dur_m=${dur_m#0}
DURATION_SECONDS=$(printf '%.0f' "$(bc -l <<< "${dur_h:-0}*3600 + ${dur_m:-0}*60 + ${dur_s:-0}")")
log "Duration: $DURATION_HUMAN ($DURATION_SECONDS seconds)"

# Load Yandex API config
CONFIG_ENV="/home/www/drive/html/apps/audio2text/spttx_data/.env"
if [ ! -f "$CONFIG_ENV" ]; then
    fail "Configuration file not found: $CONFIG_ENV"
fi

source "$CONFIG_ENV"

# Validate API credentials
if [ -z "${YANDEX_API_KEY:-}" ]; then
    fail "YANDEX_API_KEY not configured"
fi

if [ -z "${S3_BUCKET:-}" ]; then
    fail "S3_BUCKET not configured"
fi

S3_ENDPOINT="${S3_ENDPOINT:-https://storage.yandexcloud.net}"

# Export AWS credentials for aws cli
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    fail "AWS credentials not configured"
fi

log "AWS credentials configured for bucket: $S3_BUCKET"

# Create temporary .opus file (will be deleted after upload)
OPUS_NAME="$(basename "${FILENAME%.*}")_$(date +'%d-%m-%Y_%H%M%S')_tmp.opus"
OPUS_PATH="${TMP_DIR}/${OPUS_NAME}"

set_status "Converting and speeding up audio (10x faster)..."
log "Creating temporary opus file: $OPUS_PATH"

# Convert with low priority (nice/ionice)
if ! nice -n 19 ionice -c 3 ffmpeg -hide_banner -loglevel error -i "$FILE_PATH" -ac 1 -c:a libopus "$OPUS_PATH"; then
    fail "FFmpeg conversion failed"
fi

log "Opus file created: $(stat -c%s "$OPUS_PATH") bytes"

# Upload to S3 with low priority
set_status "Uploading to Yandex Cloud S3..."
log "Uploading to s3://$S3_BUCKET/$OPUS_NAME"

if ! nice -n 19 ionice -c 3 aws --endpoint-url="$S3_ENDPOINT" s3 cp "$OPUS_PATH" "s3://$S3_BUCKET/$OPUS_NAME"; then
    rm -f "$OPUS_PATH"
    fail "S3 upload failed"
fi

# Delete local .opus file immediately after upload
log "Deleting temporary opus file"
rm -f "$OPUS_PATH"

# Determine profanity filter and raw results
PROFANITY_FILTER_VALUE="${PROFANITY_FILTER:-0}"
RAW_RESULTS_VALUE="${RAW_RESULTS:-0}"
[ "$PROFANITY_FILTER_VALUE" = "1" ] && PROFANITY_FILTER_VALUE="true" || PROFANITY_FILTER_VALUE="false"
[ "$RAW_RESULTS_VALUE" = "1" ] && RAW_RESULTS_VALUE="true" || RAW_RESULTS_VALUE="false"

# Determine model
MODEL_VALUE="general"
if [ "$RAW_RESULTS_VALUE" = "true" ]; then
    MODEL_VALUE="general"  # Raw results only work with general model
fi

# Create API request
set_status "Starting speech recognition (Yandex SpeechKit)..."
log "Creating recognition task with Yandex API..."

cat > "${TMP_DIR}/params_${TASK_ID}.json" <<EOF
{
  "config": {
    "specification": {
      "languageCode": "$LANGUAGE",
      "model": "$MODEL_VALUE",
      "profanityFilter": $PROFANITY_FILTER_VALUE,
      "rawResults": $RAW_RESULTS_VALUE
    }
  },
  "audio": {"uri": "https://storage.yandexcloud.net/$S3_BUCKET/$OPUS_NAME"}
}
EOF

RESPONSE_FILE="${TMP_DIR}/response_${TASK_ID}.json"
HTTP_CODE=$(curl -s -w '%{http_code}' -o "$RESPONSE_FILE" \
    -X POST -H "Authorization: Api-Key $YANDEX_API_KEY" \
    -d "@${TMP_DIR}/params_${TASK_ID}.json" \
    https://transcribe.api.cloud.yandex.net/speech/stt/v2/longRunningRecognize)

if [ "$HTTP_CODE" != "200" ]; then
    log "API Error (HTTP $HTTP_CODE): $(cat "$RESPONSE_FILE")"
    rm -f "$RESPONSE_FILE" "${TMP_DIR}/params_${TASK_ID}.json"
    fail "Yandex API request failed"
fi

OPERATION_ID=$(grep '"id"' "$RESPONSE_FILE" | sed 's/^.*: "//; s/",*$//')
rm -f "$RESPONSE_FILE" "${TMP_DIR}/params_${TASK_ID}.json"

if [ -z "$OPERATION_ID" ]; then
    fail "Operation ID not found in API response"
fi

log "Recognition task created: $OPERATION_ID"

# Wait for recognition to complete
set_status "Waiting for recognition results..."
log "Polling for results (max 30 minutes)..."

MAX_WAIT=360  # 30 minutes (360 * 5 seconds)
WAIT_COUNT=0

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 1))

    OPERATION_STATUS=$(curl -s -H "Authorization: Api-Key $YANDEX_API_KEY" \
        "https://operation.api.cloud.yandex.net/operations/$OPERATION_ID")

    if echo "$OPERATION_STATUS" | grep -q '"done": *true'; then
        log "Recognition completed!"

        # Save result
        RESULT_FILE="${TMP_DIR}/result_${TASK_ID}.json"
        echo "$OPERATION_STATUS" > "$RESULT_FILE"

        # Extract text
        set_status "Processing results..."

        # Check if raw results (with timestamps)
        if [ "$RAW_RESULTS_VALUE" = "true" ]; then
            # Create SRT subtitle file
            RESULT_EXTENSION="srt"
            RESULT_NAME="${FILENAME%.*}.${RESULT_EXTENSION}"
            RESULT_PATH="$OUTPUT_DIR/$RESULT_NAME"

            log "Creating SRT subtitle file: $RESULT_PATH"
            cat "$RESULT_FILE" > "$RESULT_PATH"
        else
            # Create plain text file
            RESULT_EXTENSION="txt"
            RESULT_NAME="${FILENAME%.*}.${RESULT_EXTENSION}"
            RESULT_PATH="$OUTPUT_DIR/$RESULT_NAME"

            log "Creating text file: $RESULT_PATH"
            grep -o '"text": *"[^"]*"' "$RESULT_FILE" | sed 's/"text": *"//;s/"$//' | tr '\n' ' ' > "$RESULT_PATH"
        fi

        rm -f "$RESULT_FILE"

        # Update ownCloud index
        log "Updating ownCloud file index..."
        OWNCLOUD_DIR="/home/www/drive/html"
        if [ -f "$OWNCLOUD_DIR/occ" ]; then
            php "$OWNCLOUD_DIR/occ" files:scan --path="/$USER_ID/files/$(basename "$(dirname "$RESULT_PATH")")" >> "$LOG_FILE" 2>&1 || log "WARN: Failed to scan ownCloud directory"
        fi

        log "COMPLETED: Transcription finished successfully"
        log "Result file: $RESULT_NAME"
        set_status "completed"

        # Send notifications
        RESOLVE_MM_SCRIPT="/home/www/drive/html/apps/audio2text/scripts/resolve_mm_username.sh"
        SEND_MM_SCRIPT="/home/www/drive/html/apps/audio2text/scripts/send_mm_notification.sh"
        SEND_EMAIL_SCRIPT="/home/www/drive/html/apps/audio2text/scripts/send_email_notification.sh"

        # Calculate processing time
        FILE_SIZE=$(du -h "$RESULT_PATH" 2>/dev/null | cut -f1)
        PROCESSING_TIME=$(($(date +%s) - $(stat -c %Y "$FILE_PATH" 2>/dev/null || echo $(date +%s))))
        MINUTES=$((PROCESSING_TIME / 60))
        SECONDS=$((PROCESSING_TIME % 60))

        # Mattermost notification
        if [ -f "$RESOLVE_MM_SCRIPT" ] && [ -f "$SEND_MM_SCRIPT" ]; then
            log "Sending Mattermost notification..."
            MM_USERNAME=$("$RESOLVE_MM_SCRIPT" "$USER_ID" 2>/dev/null || true)

            if [ -n "$MM_USERNAME" ]; then
                OWNCLOUD_URL="https://drive.spbsot.ru"
                ORIGINAL_FILE_URL="$OWNCLOUD_URL/index.php/apps/files/?dir=/&scrollto=$(echo "$FILENAME" | sed 's/ /%20/g')"
                RESULT_FILE_URL="$OWNCLOUD_URL/index.php/apps/files/?dir=/&scrollto=$(echo "$RESULT_NAME" | sed 's/ /%20/g')"

                MM_MESSAGE="### :white_check_mark: Распознавание речи завершено

**Исходный файл:** \`$FILENAME\`
**Результат:** \`$RESULT_NAME\` (${FILE_SIZE})
**Время обработки:** ${MINUTES} мин ${SECONDS} сек

:inbox_tray: **Файл с текстом прикреплён к сообщению**

---
:page_facing_up: [Открыть результат в ownCloud]($RESULT_FILE_URL)
:file_folder: [Открыть оригинал в ownCloud]($ORIGINAL_FILE_URL)

_Автоматическое уведомление от Audio2Text_"

                "$SEND_MM_SCRIPT" "$MM_USERNAME" "$MM_MESSAGE" "$RESULT_PATH" >> "$LOG_FILE" 2>&1 || log "WARN: Failed to send Mattermost notification"
                log "Mattermost notification sent to @$MM_USERNAME"
            fi
        fi

        # Email notification
        if [ -f "$SEND_EMAIL_SCRIPT" ]; then
            log "Sending email notification..."

            EMAIL_BODY="Добрый день!

Распознавание речи для файла '$FILENAME' успешно завершено.

Информация о результате:
  Файл результата: $RESULT_NAME
  Размер: ${FILE_SIZE}
  Время обработки: ${MINUTES} мин ${SECONDS} сек

Ссылки для просмотра в ownCloud:
  Результат: https://drive.spbsot.ru/index.php/apps/files/?dir=/&scrollto=$RESULT_NAME
  Оригинал: https://drive.spbsot.ru/index.php/apps/files/?dir=/&scrollto=$FILENAME

С уважением,
Служба автоматического распознавания речи
ownCloud Audio2Text"

            "$SEND_EMAIL_SCRIPT" "${USER_ID}@edutech-group.ru" "Распознавание завершено: $FILENAME" "$EMAIL_BODY" "$RESULT_PATH" >> "$LOG_FILE" 2>&1 || log "WARN: Failed to send email"
            log "Email notification sent"
        fi

        # Cleanup config
        rm -f "$CONFIG_FILE"

        exit 0
    fi

    # Log progress every minute
    if [ $((WAIT_COUNT % 12)) -eq 0 ]; then
        log "Still waiting for results... ($((WAIT_COUNT * 5)) seconds elapsed)"
    fi
done

fail "Recognition timeout (waited $((MAX_WAIT * 5)) seconds)"
