#!/bin/bash

# Script zum Splitten der BONUS_MIX Datei nach Zeitstempeln

# Eingabedatei finden
AUDIO_FILE=$(find . -maxdepth 2 -type f \( -name "*BONUS*" -o -name "*bonus*" \) \( -name "*.mp3" -o -name "*.wav" -o -name "*.flac" -o -name "*.m4a" \) | head -1)

if [ -z "$AUDIO_FILE" ]; then
    echo "❌ BONUS_MIX Datei nicht gefunden!"
    exit 1
fi

echo "✅ Gefunden: $AUDIO_FILE"

# Ausgabeverzeichnis erstellen
OUTPUT_DIR="BONUS_MIX_Tracks"
mkdir -p "$OUTPUT_DIR"
echo "📁 Verzeichnis erstellt: $OUTPUT_DIR"

# Tracks mit Zeitstempeln (Start und Ende)
declare -a TRACKS=(
    "0:01|2:14|1 - Don't Test Me Bitch (60s soul version)"
    "2:14|4:46|2 - You Drive Like Shit (70s funk version)"
    "4:46|7:18|3 - Bitches Do Dishes (70s funk version)"
    "7:18|10:29|4 - Bitch Slap (70s funk version)"
    "10:29|13:55|5 - Snitches Get Bitches (60s soul version)"
    "13:55|16:43|6 - Coexist With My Fist (70s funk version)"
    "16:43|18:34|7 - Kool-Aid Man (70s funk version)"
    "18:34|20:27|8 - The Music Industry Must Be Destroyed (70s funk disco version)"
    "20:27|22:50|9 - Punch A Nerd (60s soul version)"
    "22:50|24:49|10 - Gigantic Shit (50s big band swing original)"
    "24:49|26:14|11 - Honk The Tonk (70s country original)"
    "26:14|27:46|12 - Whoop That Ass (60s soul gospel original)"
    "27:46|29:38|13 - Rule The World (90s rock version)"
    "29:38|31:09|14 - Moon Cricket Black as Night (60s blues original)"
    "31:09|32:56|15 - I'm The Shit (60s soul version)"
    "32:56|34:47|16 - Stop Being A Huge Bitch (70s r&b original)"
    "34:47|36:21|17 - Sparkly Balls and The Giant Wiener (70s big band swing original)"
    "36:21|38:08|18 - Gather Round Lil Niglets (60s folk original)"
    "38:08|40:38|19 - Waffle House Fight (full version)"
    "40:38|999:59|20 - Don't Test Me Bitch (70s funk version)"
)

# Tracks extrahieren
for TRACK in "${TRACKS[@]}"; do
    IFS='|' read -r START END NAME <<< "$TRACK"
    OUTPUT_FILE="$OUTPUT_DIR/$NAME.mp3"

    echo "🎵 Extrahiere: $NAME"
    ffmpeg -i "$AUDIO_FILE" -ss "$START" -to "$END" -c copy "$OUTPUT_FILE" -y 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "   ✅ Fertig: $OUTPUT_FILE"
    else
        echo "   ❌ Fehler bei: $NAME"
    fi
done

echo ""
echo "✅ Alle Tracks wurden splittet!"
ls -lh "$OUTPUT_DIR" | tail -n +2 | wc -l
echo "Tracks im Verzeichnis $OUTPUT_DIR"
