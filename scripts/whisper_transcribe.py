#!/opt/python3.9/bin/python3.9
"""
Whisper transcription script for Audio2Text OwnCloud plugin.
Uses faster-whisper for CPU-optimized inference.
"""
import sys
import os
import time

def log(log_file, msg):
    ts = time.strftime('%Y-%m-%d %H:%M:%S')
    with open(log_file, 'a') as f:
        f.write(f'[{ts}] {msg}\n')

def set_status(status_file, log_file, status):
    with open(status_file, 'w') as f:
        f.write(status)
    log(log_file, f'STATUS: {status}')

def format_srt_time(seconds):
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    ms = int((seconds % 1) * 1000)
    return f'{h:02d}:{m:02d}:{s:02d},{ms:03d}'

def main():
    if len(sys.argv) < 2:
        print("Usage: whisper_transcribe.py <config_file>")
        sys.exit(1)

    config_file = sys.argv[1]

    # Parse config (KEY="value" format)
    config = {}
    with open(config_file) as f:
        for line in f:
            line = line.strip()
            if '=' in line and not line.startswith('#'):
                key, _, value = line.partition('=')
                config[key] = value.strip('"').strip("'")

    task_id = config.get('TASK_ID', '')
    file_path = config.get('FILE_PATH', '')
    filename = config.get('FILENAME', '')
    language = config.get('LANGUAGE', 'ru-RU')
    whisper_model = config.get('WHISPER_MODEL', 'small')
    output_dir = config.get('OUTPUT_DIR', '')
    user_id = config.get('USER_ID', '')
    raw_results = config.get('RAW_RESULTS', '0')

    tmp_dir = '/home/www/drive/data/audio2text_tmp'
    log_file = os.path.join(tmp_dir, f'audio2text_{task_id}.log')
    status_file = os.path.join(tmp_dir, f'audio2text_{task_id}.status')

    try:
        log(log_file, '=== Whisper Transcription Started ===')
        log(log_file, f'Task ID: {task_id}')
        log(log_file, f'File: {filename}')
        log(log_file, f'Path: {file_path}')
        log(log_file, f'Language: {language}')
        log(log_file, f'Model: {whisper_model}')
        log(log_file, f'Output: {output_dir}')

        if not os.path.isfile(file_path):
            raise FileNotFoundError(f'File not found: {file_path}')

        set_status(status_file, log_file, 'Loading Whisper model...')

        from faster_whisper import WhisperModel

        # Map Yandex language codes to Whisper 2-letter codes
        lang_map = {
            'ru-RU': 'ru', 'en-US': 'en', 'de-DE': 'de', 'es-ES': 'es',
            'fr-FR': 'fr', 'it-IT': 'it', 'pt-BR': 'pt', 'pl-PL': 'pl',
            'nl-NL': 'nl', 'sv-SE': 'sv', 'tr-TR': 'tr', 'kk-KK': 'kk',
            'uz-UZ': 'uz', 'he-IL': 'he', 'ar-AE': 'ar', 'fi-FI': 'fi',
            'auto': None,
        }
        whisper_lang = lang_map.get(language)
        if whisper_lang is None and language not in ('auto', ''):
            whisper_lang = language[:2].lower() if len(language) >= 2 else None

        # Load model with int8 quantization for CPU
        model = WhisperModel(whisper_model, device="cpu", compute_type="int8")
        log(log_file, f'Model loaded: {whisper_model} (int8, CPU)')

        set_status(status_file, log_file, 'Transcribing with Whisper...')

        kwargs = {
            'beam_size': 5,
            'vad_filter': True,
            'vad_parameters': {'min_silence_duration_ms': 500},
        }
        if whisper_lang:
            kwargs['language'] = whisper_lang

        segments_iter, info = model.transcribe(file_path, **kwargs)

        log(log_file, f'Detected language: {info.language} (prob: {info.language_probability:.2f})')
        log(log_file, f'Duration: {info.duration:.1f}s')

        set_status(status_file, log_file, 'Processing Whisper results...')

        all_segments = list(segments_iter)
        log(log_file, f'Segments: {len(all_segments)}')

        # Create output
        base_name = os.path.splitext(filename)[0]

        if raw_results == '1':
            # SRT subtitles
            result_name = base_name + '.srt'
            result_path = os.path.join(output_dir, result_name)
            with open(result_path, 'w', encoding='utf-8') as f:
                for i, seg in enumerate(all_segments, 1):
                    f.write(f'{i}\n')
                    f.write(f'{format_srt_time(seg.start)} --> {format_srt_time(seg.end)}\n')
                    f.write(f'{seg.text.strip()}\n\n')
            log(log_file, f'SRT created: {result_name}')
        else:
            # Plain text
            txt_name = base_name + '.txt'
            txt_path = os.path.join(output_dir, txt_name)
            with open(txt_path, 'w', encoding='utf-8') as f:
                for seg in all_segments:
                    f.write(seg.text.strip() + '\n')

            # Try converting to docx via pandoc
            docx_name = base_name + '.docx'
            docx_path = os.path.join(output_dir, docx_name)
            ret = os.system(f'pandoc "{txt_path}" -o "{docx_path}" 2>/dev/null')
            if ret == 0 and os.path.isfile(docx_path):
                os.remove(txt_path)
                result_name = docx_name
                result_path = docx_path
                log(log_file, f'Converted to docx: {docx_name}')
            else:
                result_name = txt_name
                result_path = txt_path
                log(log_file, f'Text saved (pandoc unavailable): {txt_name}')

        # Fix permissions
        os.chmod(result_path, 0o644)

        # Update ownCloud index
        set_status(status_file, log_file, 'Updating ownCloud file index...')
        oc_dir = '/home/www/drive/html'
        scan_path = os.path.basename(os.path.dirname(result_path))
        os.system(f'php {oc_dir}/occ files:scan --path="/{user_id}/files/{scan_path}" 2>/dev/null')

        log(log_file, f'COMPLETED: Transcription finished successfully')
        log(log_file, f'Result file: {result_name}')
        set_status(status_file, log_file, 'completed')

        # Word count for notifications
        if result_path.endswith('.txt'):
            with open(result_path, encoding='utf-8') as f:
                word_count = len(f.read().split())
        else:
            word_count = '?'

        # Write result metadata for wrapper to pick up
        meta_file = os.path.join(tmp_dir, f'audio2text_{task_id}.meta')
        with open(meta_file, 'w') as f:
            f.write(f'RESULT_NAME="{result_name}"\n')
            f.write(f'RESULT_PATH="{result_path}"\n')
            f.write(f'WORD_COUNT="{word_count}"\n')
            f.write(f'DURATION="{info.duration:.1f}"\n')
            f.write(f'DETECTED_LANG="{info.language}"\n')

    except Exception as e:
        log(log_file, f'ERROR: {str(e)}')
        set_status(status_file, log_file, f'Error: {str(e)}')
        import traceback
        log(log_file, traceback.format_exc())
        sys.exit(1)

if __name__ == '__main__':
    main()
