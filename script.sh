#!/bin/bash

# call as ./script.sh <M3U8 playlist URL> -r (720|480|1080)
# this script relies upon pcregrep - one that supports multiline regular expressions
# 1. get the playlist
res1080="false";
res720="false";
res480="false";

function parseResolution(){
	egrep -ioe ' +-r( *|=)480 ' <<< "$@" && res480=true && return 0;
	egrep -ioe ' +-r( *|=)720 ' <<< "$@" && res720=true && return 0;
	egrep -ioe ' +-r( *|=)1080 ' <<< "$@" && res1080=true && return 0;
	return 1;
}

page="$(wget -O - "$1")";
# there are two types of m3u8 files, the first contain the urls for multiple playlists. Each playlist in
# these playlists is an m3u8 file, each playlist will have an inline specified BW and resolution, the ff
# regular expression chooses the 720p resolution playlist
regex1080='^(\#EXT-X-STREAM-INF:PROGRAM-ID=[0-9]+,BANDWIDTH=[0-9]+,RESOLUTION=(19[12][890123]x[0-9]+|[0-9]+x10[78][7890123]),FRAME-RATE=[0-9]+(\.[0-9]+)?,CODECS="[^"]+"\n)(https:\/\/.+)'
regex720='^(\#EXT-X-STREAM-INF:PROGRAM-ID=[0-9]+,BANDWIDTH=[0-9]+,RESOLUTION=(12[78][7890]x[0-9]+|[0-9]+x7[12][7890]),FRAME-RATE=[0-9]+(\.[0-9]+)?,CODECS="[^"]+"\n)(https:\/\/.+)';
regex480='^(\#EXT-X-STREAM-INF:PROGRAM-ID=[0-9]+,BANDWIDTH=[0-9]+,RESOLUTION=(8[45][890123]x[0-9]+|[0-9]+x4[78][7890]),FRAME-RATE=[0-9]+(\.[0-9]+)?,CODECS="[^"]+"\n)(https:\/\/.+)';
# makeshift argument parsing, assumes only one resolution selected
parseResolution "$@" || exit 1;
