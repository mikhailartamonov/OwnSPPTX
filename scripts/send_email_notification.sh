#!/bin/bash

# Send email notification with file attachment using msmtp
# Usage: send_email_notification.sh <to_email> <subject> <body> [attachment_path]

FROM_EMAIL="${EMAIL_FROM:-owncloud@robot.uchi-uchi.ru}"
TO_EMAIL="$1"
SUBJECT="$2"
BODY="$3"
ATTACHMENT="$4"

if [ -z "$TO_EMAIL" ] || [ -z "$SUBJECT" ] || [ -z "$BODY" ]; then
    echo "Usage: $0 <to_email> <subject> <body> [attachment_path]" >&2
    exit 1
fi

BOUNDARY="----=_NextPart_$(date +%s)_$(( RANDOM ))"

# Function to encode file in base64
encode_file() {
    local file="$1"
    base64 "$file" 2>/dev/null || openssl base64 -in "$file"
}

# Function to get MIME type
get_mime_type() {
    local file="$1"
    file -b --mime-type "$file" 2>/dev/null || echo "application/octet-stream"
}

# Build email
{
    echo "From: $FROM_EMAIL"
    echo "To: $TO_EMAIL"
    echo "Subject: $SUBJECT"
    echo "MIME-Version: 1.0"
    echo "Content-Type: multipart/mixed; boundary=\"$BOUNDARY\""
    echo ""
    echo "--$BOUNDARY"
    echo "Content-Type: text/plain; charset=UTF-8"
    echo "Content-Transfer-Encoding: 8bit"
    echo ""
    echo "$BODY"
    echo ""

    # Add attachment if provided
    if [ -n "$ATTACHMENT" ] && [ -f "$ATTACHMENT" ]; then
        FILENAME=$(basename "$ATTACHMENT")
        MIME_TYPE=$(get_mime_type "$ATTACHMENT")

        echo "--$BOUNDARY"
        echo "Content-Type: $MIME_TYPE; name=\"$FILENAME\""
        echo "Content-Transfer-Encoding: base64"
        echo "Content-Disposition: attachment; filename=\"$FILENAME\""
        echo ""
        encode_file "$ATTACHMENT"
        echo ""
    fi

    echo "--$BOUNDARY--"
} | /usr/bin/msmtp -t

if [ $? -eq 0 ]; then
    echo "Email sent successfully to $TO_EMAIL"
    if [ -n "$ATTACHMENT" ] && [ -f "$ATTACHMENT" ]; then
        echo "With attachment: $(basename "$ATTACHMENT")"
    fi
    exit 0
else
    echo "ERROR: Failed to send email" >&2
    exit 1
fi
