Download & install
https://play.google.com/store/apps/details?id=com.termux
https://f-droid.org/en/packages/com.termux/

Step 1: Update and upgrade Termux packages
pkg update && pkg upgrade

Step 2: Install required dependencies
pkg install x11-repo
pkg install ffmpeg

x11-repo is needed for some multimedia packages.
ffmpeg is the tool that processes and normalizes your audio.

Note:
Make sure Termux has storage permissions:
termux-setup-storage
This will allow Termux to access /sdcard.
On higher versions of Android, you must manually grant “All files access” to Termux.

Step 3: Move and run your script
If you saved your script in your Android shared storage, move it to your Termux home and make it executable:
#Move: mv /storage/emulated/0/normalize.sh ~/normalize.sh
#Executable: chmod +x ~/normalize.sh
~/normalize.sh

---Loudness Normalization Script for MP3 Files---

# This script normalizes the loudness of audio files to a consistent level using FFmpeg's loudnorm filter and applies a limiter to prevent distortion. It provides consistent and safe listening levels, especially at 100% volume, though the final result also depends on the original audio quality and dynamic range of the content. Since this process applies static gain adjustment with peak limiting, there's no need to consider LRA (Loudness Range), as we are not performing dynamic compression.
# Recommended Integrated Loudness (LUFS):
# -14 LUFS (standard for streaming platforms, safe for headphones)
# -16 LUFS (safer, better for background or long sessions)
# -18 LUFS (extra safe for speakers or very sensitive ears)
#
# Recommended True Peak (TP) values:
# - For -14 LUFS → TP = -1.0 dB
# - For -16 or -18 LUFS → TP = -1.5 dB
# ------------------------------------------------------------------
#Common LUFS Levels in Practice: Use Case / Platform Typical LUFS
#Spotify (normalized)	-14 LUFS Will turn down louder tracks; recommends mastering to -14
#Apple Music (Sound Check)	~-16 LUFS
#YouTube -14 LUFS
#Classical music remasters	-20 to -23 LUFS	Preserves wide dynamics
#Pop music remasters	-9 to -6 LUFS Prioritizes loudness over dynamic range
#Dynamic-range-conscious remasters (e.g., vinyl rips or audiophile versions)	-14 to -18 LUFS	More balanced sound.

#Most commercially released songs are not remastered to a single LUFS standard—instead, they tend to be louder than -14 LUFS, often around -9 to -6 LUFS integrated, especially in pop, hip-hop, and EDM. This is due to the "loudness war," where tracks are mastered as loud as possible without clipping.

#Understanding LUFS Targets: Loud vs Quiet
LUFS (Loudness Units Full Scale) is a way of measuring how loud audio feels to our ears, not just how big the waveforms look. It's the standard used for loudness normalization across platforms like Spotify, YouTube, and Apple Music.
General Rule:
The higher the LUFS number (closer to 0) → Louder the audio.
The lower the LUFS number (more negative) → Quieter the audio.

#Target LUFS   Perceived Loudness	Typical Use Case
-14 LUFS	Louder	Streaming platforms (Spotify, YouTube)
-16 LUFS	Moderate	Safer for long listening, background audio
-18 LUFS	Quieter	Great for speakers, podcasts, or dynamic content
-23 LUFS	Very quiet	Broadcasting standards (e.g. TV in Europe)
Example:
If a track is at -6 LUFS, it's very loud (common in commercial pop/EDM). If it's at -20 LUFS, it’s much quieter, with more headroom and dynamics (like classical music).

#Recommended Device Volume: 70–80% (Wired or Headphone)
#Whether you're using a wired headset or a Bluetooth headset, it's recommended to keep your device volume between 70% and 80% for these reasons:
#Hearing safety: Listening at maximum volume for long periods can cause hearing damage. 70–80% is generally considered safe for extended use.
#Audio quality: Many devices introduce distortion at 100% volume, especially on Bluetooth. Staying under 80% helps preserve sound clarity.
#Headroom: This leaves space for dynamic peaks in music (like kicks or vocals) without clipping or harshness, especially if using EQ or enhanced bass.
#Even if your audio is loudness normalized, the device volume still affects how intense the sound feels in your ears.

#This is not opinion — it's a known tradeoff in audio engineering
Professional mastering engineers and developers working with LUFS know this:
Stereo gives a richer experience.
Mono gives more predictable loudness behavior.

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
