#!/bin/bash

# call as ./script.sh <M3U8 playlist URL>
# this script relies upon pcregrep - one that supports multiline regular expressions
# 1. get the playlist
page="$(wget -O - "$1")";

# there are two types of m3u8 files, the first contain the urls for multiple playlists. Each playlist in
# these playlists is an m3u8 file, each playlist will have an inline specified BW and resolution, the ff
# regular expression chooses the 720p resolution playlist
regex1080='^(\#EXT-X-STREAM-INF:PROGRAM-ID=[0-9]+,BANDWIDTH=[0-9]+,RESOLUTION=(19[12][890123]x[0-9]+|[0-9]+x10[78][7890123]),FRAME-RATE=[0-9]+(\.[0-9]+)?,CODECS="[^"]+"\n)(https:\/\/.+)'
regex720='^(\#EXT-X-STREAM-INF:PROGRAM-ID=[0-9]+,BANDWIDTH=[0-9]+,RESOLUTION=(12[78][7890]x[0-9]+|[0-9]+x7[12][7890]),FRAME-RATE=[0-9]+(\.[0-9]+)?,CODECS="[^"]+"\n)(https:\/\/.+)';
regex480='^(\#EXT-X-STREAM-INF:PROGRAM-ID=[0-9]+,BANDWIDTH=[0-9]+,RESOLUTION=(8[45][890123]x[0-9]+|[0-9]+x4[78][7890]),FRAME-RATE=[0-9]+(\.[0-9]+)?,CODECS="[^"]+"\n)(https:\/\/.+)';

for i in $@
	do


done