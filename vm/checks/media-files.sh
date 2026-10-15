# Run in the VM by vm/test-install as the desktop user. Decision record 0044:
# common formats play and archives open. Generates short samples with ffmpeg
# (installed with gst-libav), plays each through GStreamer's playbin (what
# Showtime and Decibels use) into fake sinks, then makes 7z and zip archives
# and extracts them with 7z, unzip and libarchive (what Files uses).
set -u
fail() { echo "media check: $*"; exit 1; }
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
cd "$d" || exit 1
ff() { ffmpeg -nostdin -hide_banner -loglevel error -y "$@" || fail "ffmpeg could not make ${*: -1}"; }
ff -f lavfi -i testsrc2=size=320x240:rate=25:duration=2 -f lavfi -i sine=frequency=440:duration=2 \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest h264-aac.mp4
ff -f lavfi -i sine=frequency=440:duration=2 -c:a libopus opus.opus
ff -f lavfi -i sine=frequency=440:duration=2 -c:a flac flac.flac
ff -f lavfi -i sine=frequency=440:duration=2 -c:a libmp3lame mp3.mp3

for f in h264-aac.mp4 opus.opus flac.flac mp3.mp3; do
  out=$(timeout 60 gst-launch-1.0 -q playbin "uri=file://$d/$f" audio-sink=fakesink video-sink=fakesink 2>&1) \
    || fail "GStreamer could not play $f: $out"
  info=$(gst-discoverer-1.0 "$f" 2>&1)
  grep -q 'Duration: 0:00:0[12]' <<<"$info" || fail "no duration for $f: $info"
done
gst-discoverer-1.0 h264-aac.mp4 | grep -qi 'H.264' || fail "mp4 not seen as H.264"
gst-discoverer-1.0 h264-aac.mp4 | grep -qi 'AAC' || fail "mp4 not seen as AAC"
gst-inspect-1.0 avdec_h264 >/dev/null 2>&1 || fail "gst-libav's H.264 decoder missing"

mkdir src; echo "archive test" > src/note.txt
7z a -bd -t7z a.7z src >/dev/null || fail "7z could not create a.7z"
7z a -bd -tzip a.zip src >/dev/null || fail "7z could not create a.zip"
mkdir x1 x2 x3
7z x -bd -ox1 a.7z >/dev/null && grep -qx "archive test" x1/src/note.txt || fail "7z x a.7z"
unzip -q a.zip -d x2 && grep -qx "archive test" x2/src/note.txt || fail "unzip a.zip"
bsdtar -xf a.7z -C x3 && grep -qx "archive test" x3/src/note.txt || fail "libarchive a.7z"
7z i | grep -q 'Rar5' || fail "7z has no RAR support"
echo ok
