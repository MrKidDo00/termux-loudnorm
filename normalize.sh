#!/bin/bash

# Set your parameters
INPUT_DIR="/storage/emulated/0/Music/Telegram"       # Replace with your input directory
OUTPUT_DIR="/storage/emulated/0/Music"    # Replace with your output directory
TARGET_LUFS=-12                 # Target loudness in LUFS
MAX_TRUE_PEAK_DB=-1.5           # Maximum true peak in dB

# FFmpeg output parameters
OUTPUT_SAMPLE_RATE=48000        # -ar
OUTPUT_CHANNELS=2               # -ac
OUTPUT_CODEC="libmp3lame"       # -c:a
OUTPUT_QUALITY=2                # -qscale:a

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Loop through all MP3 files in input directory
for input_file in "$INPUT_DIR"/*.mp3; do
    base_name=$(basename "$input_file" .mp3)
    output_file="$OUTPUT_DIR/${base_name}_normalized.mp3"

    echo "Analyzing $base_name..."

    # Analyze loudness stats using FFmpeg loudnorm
    stats=$(ffmpeg -hide_banner -i "$input_file" \
        -af "loudnorm=I=$TARGET_LUFS:TP=$MAX_TRUE_PEAK_DB:print_format=json" \
        -f null - 2>&1)

    # Extract input LUFS and True Peak
    input_i=$(echo "$stats" | grep -oP '"input_i"\s*:\s*"-?\d+\.?\d*"' | cut -d ':' -f2 | tr -d ' "')
    input_tp=$(echo "$stats" | grep -oP '"input_tp"\s*:\s*"-?\d+\.?\d*"' | cut -d ':' -f2 | tr -d ' "')

    if [ -z "$input_i" ] || [ -z "$input_tp" ]; then
        echo "Could not read LUFS or TP for $base_name. Skipping."
        continue
    fi

    echo "Measured LUFS: $input_i dB"
    echo "Measured True Peak: $input_tp dB"

    # Calculate gain to apply
    gain=$(awk "BEGIN { printf \"%.2f\", $TARGET_LUFS - $input_i }")
    echo "Applied gain: $gain dB"

    # Apply gain only (no limiter), output normalized MP3 using variables
    ffmpeg -hide_banner -i "$input_file" \
        -af "volume=${gain}dB" \
        -ar $OUTPUT_SAMPLE_RATE -ac $OUTPUT_CHANNELS -c:a $OUTPUT_CODEC -qscale:a $OUTPUT_QUALITY \
        "$output_file"

done

echo "Done: All files processed."