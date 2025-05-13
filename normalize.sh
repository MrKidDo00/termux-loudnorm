# Input and output directories
INPUT_DIR="/sdcard/Music/Telegram/"
OUTPUT_DIR="/sdcard/Download/EncodedMusic/Normalized"
TARGET_LUFS = -14 
MAXIMUM_TP = -1.0

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Loop through each MP3 file in the input directory
for input_file in "$INPUT_DIR"/*.mp3; do
  base_name=$(basename "$input_file")
  output_file="$OUTPUT_DIR/$base_name"

  echo "Analyzing $base_name..."

  # Step 1: Analyze file to get current loudness (input_i)
  stats=$(ffmpeg -hide_banner -i "$input_file" \
    -af "loudnorm=I=$TARGET_LUFS:TP=$MAXIMUM_TP:print_format=json" \
    -f null - 2>&1)

  # Extract the input integrated loudness value from the JSON output
  input_i=$(echo "$stats" | grep -oP '"input_i"\s*:\s*"-?\d+\.?\d*"' | cut -d ':' -f2 | tr -d ' "')

  # If loudness reading fails, skip this file
  if [ -z "$input_i" ]; then
    echo "Could not read LUFS for $base_name. Skipping."
    continue
  fi

  # Step 2: Calculate the gain needed to reach target loudness
  gain=$(awk "BEGIN { printf \"%.2f\", $TARGET_LUFS - $input_i }")
  echo "Applying gain: $gain dB to match target of $TARGET_LUFS LUFS"

  # Step 3: Apply the gain and a limiter to avoid clipping
  ffmpeg -hide_banner -i "$input_file" \
    -af "volume=${gain}dB,alimiter=limit=0.89" \
    -ab 320k -ar 48000 -ac 2 "$output_file"
done

echo "Done: All files processed."
