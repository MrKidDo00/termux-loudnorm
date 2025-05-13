INPUT_DIR="/sdcard/Music/Telegram/"
OUTPUT_DIR="/sdcard/Download/EncodedMusic/Lufs_Normalized"
TARGET_LUFS=-14
MAX_TRUE_PEAK_DB=-1.0  # dBFS
mkdir -p "$OUTPUT_DIR"

# Convert MAX_TRUE_PEAK_DB to linear scale
MAX_TRUE_PEAK_LINEAR=$(awk "BEGIN { printf \"%.6f\", 10^($MAX_TRUE_PEAK_DB/20) }")
echo "Limiter ceiling in linear scale: $MAX_TRUE_PEAK_LINEAR"

for input_file in "$INPUT_DIR"/*.mp3; do
  base_name=$(basename "$input_file" .mp3)
  output_file="$OUTPUT_DIR/${base_name}_normalized.mp3"

  echo "Analyzing $base_name..."

  # Analyze loudness stats
  stats=$(ffmpeg -hide_banner -i "$input_file" \
    -af "loudnorm=I=$TARGET_LUFS:TP=$MAX_TRUE_PEAK_DB:print_format=json" \
    -f null - 2>&1)

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

  # Apply gain and limiter, output to MP3
  ffmpeg -hide_banner -i "$input_file" \
    -af "volume=${gain}dB,alimiter=limit=${MAX_TRUE_PEAK_LINEAR}", -ar 48000 -ac 2 -c:a libmp3lame -qscale:a 2 \
    "$output_file"
done

echo "Done: All files processed."
