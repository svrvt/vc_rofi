#!/bin/bash

themedir="$HOME/.config/rofi"
themename="config"
TMPDIR="$TMP/records"
DESTDIR="${XDG_VIDEOS_DIR:-${HOME}/media/video}"/screen

[[ ! -f $TMPDIR ]] && mkdir -p "$TMPDIR"
[[ ! -f $DESTDIR ]] && mkdir -p "$DESTDIR"

prompt() {
	rofi -theme-str 'window {location: center; anchor: center; fullscreen: false; height: 120px; width: 360px;}' \
		-theme-str 'mainbox {children: [ "message", "listview" ];}' \
		-theme-str 'listview {columns: 1; lines: 1;}' \
		-theme-str 'element-text {horizontal-align: 0.5;}' \
		-theme-str 'textbox {horizontal-align: 0.5;}' \
		-dmenu \
		-p 'Confirmation' \
		-mesg "$*" \
		-theme "${themedir}/${themename}".rasi
}

screenrec() {
	ffmpeg -y \
		-f x11grab \
		-s "$(xdpyinfo | awk '/dimensions/ {print $2;}')" \
		-i "$DISPLAY" \
		-c:v libx264 -qp 0 -r 30 \
		"$TMPDIR/vid.mp4" &
	echo -n 'vid-' >>/tmp/recname
}

arearec() {
	slop -f "%x %y %w %h" >/tmp/slop
	read -r X Y W H </tmp/slop
	rm /tmp/slop

	ffmpeg -y \
		-f x11grab \
		-framerate 60 \
		-video_size "$W"x"$H" \
		-i :0.0+"$X,$Y" \
		-c:v libx264 -qp 0 -r 30 \
		"$TMPDIR/vid.mp4" &
	echo -n 'box-' >>/tmp/recname
}

audiodeskrec() {
	ffmpeg -y \
		-f pulse -i 1 \
		-c:a mp3 \
		"$TMPDIR/deskaudio.mp3" &
	echo -n 'adesk-' >>/tmp/recname
}

micrec() {
	ffmpeg -y \
		-f alsa -i default \
		-c:a mp3 \
		"$TMPDIR/micaudio.mp3" &
	echo -n 'mic-' >>/tmp/recname
}

startrec() {
	SIZE="$(echo -e "Fullscreen\nArea" | prompt "Fullscreen or Area?
  (Esc = no video)")"
	DESKAUDIO="$(echo -e "Yes\nNo" | prompt "Record desktop audio?")"
	MIC="$(echo -e "Yes\nNo" | prompt "Record microphone?")"

	if [ "$SIZE" = "Fullscreen" ]; then
		screenrec
	elif [ "$SIZE" = "Area" ]; then
		arearec
	fi

	if [ "$DESKAUDIO" = "Yes" ]; then
		audiodeskrec
	fi

	if [ "$MIC" = "Yes" ]; then
		micrec
	fi

	date '+%d-%m-%Y_%H:%M:%S' >/tmp/recdate
}

mergefiles() {
	cd "$TMPDIR" || exit

	COUNT=0
	for f in *.mp3; do
		COUNT=$((++COUNT))
		echo "-i $f"
	done >mp3list

	ffmpeg -y $(cat mp3list) -filter_complex amix=inputs=$(echo $COUNT):duration=longest output.mp3

	EXTENS="mp3"
	if [ -f *.mp4 ]; then
		ffmpeg -y -i *.mp4 -i output.mp3 -c copy output.mp4
		mv *.mp4 output.mp4
		rm *.mp3
		EXTENS="mp4"
	fi

	mv output.mp* "$DESTDIR/$(cat /tmp/recname && cat /tmp/recdate).$EXTENS"
	rm *.mp4
	rm *.mp3
	rm mp3list
}

stoprec() {
	STOP="$(echo -e "Yes\nNo" | prompt "Stop Recording?")"
	if [ "$STOP" = "Yes" ]; then
		killall ffmpeg
		mergefiles
		rm /tmp/recname
	fi
}

if [ -f /tmp/recname ]; then
	stoprec
else
	startrec
fi
