#!/bin/sh

# Bookmark locations
brave="$XDG_CONFIG_HOME/BraveSoftware/Brave-Browser/Default/Bookmarks"
surfraw="$XDG_CONFIG_HOME/surfraw/bookmarks"
firefox="$HOME/.mozilla/firefox/path/to/places.sqlite"
librewolf="$HOME/.librewolf/path/to/places.sqlite"
googlechrome="$HOME/.config/google-chrome/Default/Bookmarks"
# Browser specific parsers

# Surfraw
surfr() {
	cut -f2,4- $1
}

# Chrome, Chromium, Brave
chrome() {
	jq -r '.roots[] | recurse(.children[]?) | select(.type != "folder") | {url, name} | join("\n")' $1 | paste - -
}

# Firefox, Librewolf
moz() {
	query="select moz_places.id, moz_places.url, moz_places.title, moz_bookmarks.parent from moz_places left outer join moz_bookmarks on moz_places.id = moz_bookmarks.fk;"
	sqlite3 -separator '	' "$1" "$query" | cut -f2,3
}

sr $({
	chrome $googlechrome &
	chrome $brave &
	surfr $surfraw &
	moz $firefox &
	moz $librewolf
} | sort | awk '!x[$1]++' | dmenu -l 20 | awk '{print $1}')
