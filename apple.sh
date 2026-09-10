#!/bin/bash

#install deps
sudo apt-get install ffmpeg yt-dlp potrace

#cleanup
rm -rf frames
rm bad_apple.mp*
mkdir frames

#download video
yt-dlp https://www.youtube.com/watch?v=FtutLA63Cp8 -t mp4 -o bad_apple.mp4 --no-warnings --progress

#extract frames from video
ffmpeg -i bad_apple.mp4 -r 30 frames/output_%04d.bmp -hide_banner -loglevel warning -stats

#convert frames to svg
potrace -s --group frames/* --progress 2>&1 | tr '\r' '\n' | awk '/[0-9]+%/ {printf "\rProgress: %s", $0}'

#cleanup
rm frames/*.bmp
rm bad_apple.mp*

# slim down file
echo "removing potrace watermark to slim down File"
sed -i '/<metadata>/,/<\/metadata>/d' frames/*.svg

echo "adding frames into single animation"
OUTPUT="bad_apple.svg"
FPS="30"
DIR="frames/"

# Calculate durations
FRAME_DUR=$(awk "BEGIN {printf \"%.4f\", 1/$FPS}")

# Get sorted list of SVG files in directory
FILES=($(ls "$DIR"/*.svg 2>/dev/null | grep -v "$OUTPUT" | sort -V))
TOTAL_FRAMES=${#FILES[@]}

if [ "$TOTAL_FRAMES" -eq 0 ]; then
  echo "Error: No SVG files found in $DIR"
  exit 1
fi

TOTAL_DUR=$(awk "BEGIN {printf \"%.4f\", $FRAME_DUR * $TOTAL_FRAMES}")

# Start building the combined SVG
cat <<EOF > "$OUTPUT"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 480" width="640" height="480">
EOF

# Process all files natively inside a single AWK execution pass
awk -v dur="$FRAME_DUR" -v total="$TOTAL_FRAMES" '
BEGIN {
  frame = 0
}

# FNR == 1 triggers every time AWK starts reading a new file
FNR == 1 {
  # Close the previous frame tag if this isn`t the very first file
  if (frame > 0) {
    print "  </g>"
  }

  # Calculate start and end times matching your exact Bash math
  begin_t = sprintf("%.4f", frame * dur)
  end_t   = sprintf("%.4f", (frame + 1) * dur)

  # Output exact frame wrapper header
  printf "  <g id=\"frame-%d\" visibility=\"hidden\">\n", frame
  printf "    <set attributeName=\"visibility\" to=\"visible\" begin=\"%ss; animation.repeat + %ss\" end=\"%ss; animation.repeat + %ss\" />\n", begin_t, begin_t, end_t, end_t

  # Terminal counter progress update
  printf "\rProcessing Frame %d / %d", frame, total > "/dev/stderr"

  frame++
  in_svg = 0
}

# Matching your exact extraction logic
/<\/svg>/ { 
  in_svg = 0 
}

in_svg { 
  print 
}

/<svg/ { 
  in_svg = 1 
  # Skip past multi-line <svg ... > header
  while (in_svg && !/>/) { 
    if (getline <= 0) break
  }
}

END {
  # Always close the final frame tag
  if (frame > 0) {
    print "  </g>"
  }
  printf "\rProcessing Frame %d / %d\n", total, total > "/dev/stderr"
}
' "${FILES[@]}" >> "$OUTPUT"

# Close SVG root
echo "</svg>" >> "$OUTPUT"

echo "Successfully created: $OUTPUT"

rm -rf frames
