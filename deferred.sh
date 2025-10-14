#!/bin/bash
set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

ROOT_DIR="/root/spttx"
LOG_FILE="$ROOT_DIR/def_logs"
CONFIG_FILE="$ROOT_DIR/.env"
MAX_RETRIES=20

log() {
    local level="$1"
    shift || true
    local message="$*"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts][$level] $message" >> "$LOG_FILE"
}

info() {
    log INFO "$*"
}

warn() {
    log WARN "$*"
}

error() {
    log ERROR "$*"
    echo "$*" >&2
}

fail() {
    local message="$1"
    error "$message"
    exit "${2:-1}"
}

# Parameters populated via spttx.sh
id="$1"
file_out="$2"
upload="$3"
def_name="$4"
def_time_unit="$5"
def_time_value="$6"
api_key="$7"
fownusermail=$0
file="$8"
fownuser="$9"
mds="$aa"
bucket="$bb"
model="$cc"
duration_human="$dd"
duration_seconds="$ee"
price_rub="$ff"
target_dir="$gg"

EMAIL_FROM="owncloud@robot.uchi-uchi.ru"
if [[ -f "$CONFIG_FILE" ]]; then
    set -a
    source "$CONFIG_FILE"
    set +a
fi

EMAIL_FROM="${EMAIL_FROM:-owncloud@robot.uchi-uchi.ru}"

RETRY_FILE="$ROOT_DIR/.retry_${mds}.count"
ready_file="$ROOT_DIR/ready_tst_${mds}"

target_dir="${target_dir%/}/"

attempt=0
if [[ -f "$RETRY_FILE" ]]; then
    attempt=$(cat "$RETRY_FILE" 2>/dev/null || echo 0)
fi
attempt=$((attempt + 1))
echo "$attempt" > "$RETRY_FILE"
info "Run #$attempt for task $id ($file)"

if (( attempt > MAX_RETRIES )); then
    warn "Retry limit reached for $file (id: $id)"
    rm -f "$RETRY_FILE" "$ready_file" "$ROOT_DIR/$def_name"

    failure_email="$ROOT_DIR/email.temp"
    {
        echo "From: $EMAIL_FROM"
        echo "To: $fownusermail"
        echo "Subject: Не удалось обработать звуковой файл $file"
        echo "Content-Type: text/plain; charset=UTF-8"
        echo
        echo "Добрый день!"
        echo
        echo "К сожалению, файл '$file' не удалось расшифровать после $MAX_RETRIES попыток."
        echo "Пожалуйста, попробуйте загрузить файл повторно позже или обратитесь в поддержку."
        echo
        echo "С уважением, Ваш робот"
    } > "$failure_email"

    /usr/sbin/sendmail "$fownusermail" < "$failure_email"
    rm -f "$failure_email"
    exit 1
fi

# Query Yandex operation status
tmp_status=$(mktemp)
http_code=$(curl -s -H "Authorization: Api-Key $api_key" \
    -w '%{http_code}' -o "$tmp_status" \
    "https://operation.api.cloud.yandex.net/operations/$id")

if [[ "$http_code" != "200" ]]; then
    error "Operation status request failed (HTTP $http_code) for $id: $(cat "$tmp_status")"
    rm -f "$tmp_status"
    exit 1
fi

mv "$tmp_status" "$ready_file"
ready=$(grep '"done"' "$ready_file" | head -n1 | grep -o 'true\|false' || echo "false")

if [[ "$ready" == "false" ]]; then
    next_run=$(date -d "now + ${def_time_value:-2} ${def_time_unit:-min}" +'%H:%M')
    info "Task $id not ready yet. Rescheduling at $next_run"
    if ! echo "$ROOT_DIR/$def_name" | at "$next_run" >> "$LOG_FILE" 2>&1; then
        error "Failed to schedule retry for $id"
        exit 1
    fi
    exit 0
fi

text_file_path="${target_dir}text/${file_out}$(date +"_%d-%m-%Y_%H%M")_${model}.txt"
docx_file_path="${text_file_path%.txt}.docx"
mkdir -p "${target_dir}text"

if ! grep '"text"' "$ready_file" | sed 's/^.*: "//' | sed 's/",*$//' | sed -e G > "$text_file_path"; then
    fail "Failed to extract text for $id"
fi

word_count=$(wc -w < "$text_file_path" | tr -d ' ')
char_count=$(wc -m < "$text_file_path" | tr -d ' ')

if ! pandoc "$text_file_path" -o "$docx_file_path"; then
    fail "pandoc conversion failed for $text_file_path"
fi
rm -f "$text_file_path"

info "Result saved to $(basename "$docx_file_path")"

if ! aws --endpoint-url="https://storage.yandexcloud.net" s3 rm "s3://$bucket/$upload"; then
    warn "Failed to remove uploaded audio $upload from bucket $bucket"
fi
rm -f "$ready_file" "$ROOT_DIR/$def_name"
rm -f "$RETRY_FILE"

chmod -R 644 "$target_dir"
chmod -R +x "$target_dir"
chown -R apache. "$target_dir"

sudo -u apache /home/www/drive/html/occ files:scan --path=$fownuser/files/audio2text >> "$LOG_FILE" 2>&1 || warn "occ scan failed for $fownuser"

DRIVE_URL="https://drive.uchi-uchi.ru"
TEXT_DIR_URL="${DRIVE_URL}/index.php/apps/files/?dir=/audio2text/text"
DOCX_NAME=$(basename "$docx_file_path")
DOCX_URL="${DRIVE_URL}/index.php/apps/files/?dir=/audio2text/text&openfile=$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$DOCX_NAME")"

minutes_total=$(printf '%.1f' "$(bc -l <<< "$duration_seconds/60")")

email_file="$ROOT_DIR/email.temp"
{
    echo "From: $EMAIL_FROM"
    echo "To: $fownusermail"
    echo "Subject: Звуковой файл $file обработан"
    echo "Content-Type: text/plain; charset=UTF-8"
    echo
    echo "Добрый день!"
    echo
    echo "Файл '$file' успешно расшифрован."
    echo
    echo "Результат: ${DOCX_NAME}"
    echo "Открыть: $DOCX_URL"
    echo
    echo "Характеристики:"
    echo "- Длительность аудио: $duration_human (≈ ${minutes_total} мин)"
    echo "- Объём текста: ${word_count} слов, ${char_count} символов"
    echo "- Модель распознавания: $model"
    echo "- Примерная стоимость: ${price_rub} ₽"
    echo
    echo "-------------------"
    echo "С уважением, Ваш робот"
} > "$email_file"

/usr/sbin/sendmail "$fownusermail" < "$email_file"
rm -f "$email_file"

MM_USERNAME=$(/root/spttx/scripts/resolve_mm_username.sh "$fownuser" 2>/dev/null || true)
if [[ -n "$MM_USERNAME" ]]; then
    MM_MESSAGE=$(FILE="$file" DOC="$DOCX_NAME" DOC_URL="$DOCX_URL" DURATION="$duration_human" MINUTES="$minutes_total" WORDS="$word_count" PRICE="$price_rub" FOLDER_URL="$TEXT_DIR_URL" python3 - <<'PY'
import os

def escape_md(text: str) -> str:
    for ch in ['\\', '`', '*', '_', '[', ']', '(', ')']:
        text = text.replace(ch, '\\' + ch)
    return text

file_name = escape_md(os.environ['FILE'])
doc_name = escape_md(os.environ['DOC'])
doc_url = os.environ['DOC_URL']
duration = escape_md(os.environ['DURATION'])
minutes = os.environ['MINUTES']
words = os.environ['WORDS']
price = os.environ['PRICE']
folder_url = os.environ['FOLDER_URL']

message = (
    f"✅ **Файл `{file_name}` расшифрован**\n\n"
    f"📄 [{doc_name}]({doc_url})\n\n"
    f"⌛ Длительность: {duration} (≈ {minutes} мин)\n"
    f"📝 Объём текста: {words} слов\n"
    f"💰 Примерная стоимость: {price} ₽\n\n"
    f"🔗 [Открыть папку]({folder_url})"
)
print(message)
PY
)
    /root/spttx/scripts/send_mm_notification.sh "$MM_USERNAME" "$MM_MESSAGE" >> "$LOG_FILE" 2>&1 || warn "Failed to send Mattermost notification for $fownuser"
else
    warn "Mattermost username not found for $fownuser"
fi

exit 0
