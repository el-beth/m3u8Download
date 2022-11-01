#!/bin/bash

# call as ./script.sh <M3U8 playlist URL> -r (720|480|1080) [ -s <url to playlist file that contains .ts> ] [ -o <filename for output> ] [-t <tmpdir name for previously interrupted download>]
# this script relies upon ffmpeg, pcregrep - one that supports multiline regular expressions
# 1. get the playlist
regex1080='^(\#EXT-X-STREAM-INF:PROGRAM-ID=[0-9]+,BANDWIDTH=[0-9]+,RESOLUTION=(19[12][890123]x[0-9]+|[0-9]+x10[78][7890123]),FRAME-RATE=[0-9]+(\.[0-9]+)?,CODECS="[^"]+"\n)(https:\/\/.+)'
regex720='^(\#EXT-X-STREAM-INF:PROGRAM-ID=[0-9]+,BANDWIDTH=[0-9]+,RESOLUTION=(12[78][7890]x[0-9]+|[0-9]+x7[12][7890]),FRAME-RATE=[0-9]+(\.[0-9]+)?,CODECS="[^"]+"\n)(https:\/\/.+)';
regex480='^(\#EXT-X-STREAM-INF:PROGRAM-ID=[0-9]+,BANDWIDTH=[0-9]+,RESOLUTION=(8[45][890123]x[0-9]+|[0-9]+x4[78][7890]),FRAME-RATE=[0-9]+(\.[0-9]+)?,CODECS="[^"]+"\n)(https:\/\/.+)';
res1080="false";
res720="false";
res480="false";
url="";
callingUrl="$1";
page="$(wget -q -O - "$callingUrl")";
function parseResolution(){
	egrep -qioe ' +-r( *|=)480' <<< "$@" && res480=true && return 0;
	egrep -qioe ' +-r( *|=)720' <<< "$@" && res720=true && return 0;
	egrep -qioe ' +-r( *|=)1080' <<< "$@" && res1080=true && return 0;
	return 1;
}

function filterURL(){
	url="$([ "$res480" == "true" ] && pcregrep -M "$regex480" <<< "$page" | egrep -m 1 -ioe 'https:\/\/[^ ]+\.m3u8')" && return 0;
	url="$([ "$res720" == "true" ] && pcregrep -M "$regex720" <<< "$page" | egrep -m 1 -ioe 'https:\/\/[^ ]+\.m3u8')" && return 0;
	url="$([ "$res1080" == "true" ] && pcregrep -M "$regex1080" <<< "$page" | egrep -m 1 -ioe 'https:\/\/[^ ]+\.m3u8')" && return 0;
	[ -z "$url" ] && return 1;
}
# there are two types of m3u8 files, the first contain the urls for multiple playlists. Each playlist in
# these playlists is an m3u8 file, each playlist will have an inline specified BW and resolution, the ff
# regular expression chooses the 720p resolution playlist
# makeshift argument parsing, assumes only one resolution selected
parseResolution "$@" || exit 1;
filterURL || exit 2;
# the ff regex's component for filtering domain names is in accordance with ICANN guidelines, the TLD pattern however isn't
# hlsPlaylist="$(wget -q -O - "$url" | egrep -ioe '^https:\/\/[-0-9a-zßàÁâãóôþüúðæåïçèõöÿýòäœêëìíøùîûñé]{2}(-[0-9a-zßàÁâãóôþüúðæåïçèõöÿýòäœêëìíøùîûñé]|[0-9a-zßàÁâãóôþüúðæåïçèõöÿýòäœêëìíøùîûñé]-|[0-9a-zßàÁâãóôþüúðæåïçèõöÿýòäœêëìíøùîûñé]{2})?[-0-9a-zßàÁâãóôþüúðæåïçèõöÿýòäœêëìíøùîûñé]{0,59}\.[a-z0-9]+\/[^ ]+')";
hlsPlaylist="$(wget -q -O - "$url" | egrep -ioe 'https?:\/\/[^ ]+')"
[ -z "$hlsPlaylist" ] && exit 3;
outputName=$(egrep -ioe ' -o(=| +)([^ ]+)' <<< "$@" | sed -Ee 's/ -o(=| +)([^ ]+)/\2/g');
[ -z "$outputName" ] && outputName="vid_$RANDOM.ts";
tmpDir="$(egrep -ioe ' -t(=| +)([^ ]+)' <<< "$@" | sed -Ee 's/ -t(=| +)([^ ]+)/\2/gi')";
[ -z "$tmpDir" ] && tmpDir="$RANDOM";
echo "temp dir is $tmpDir";
[ ! -d "$tmpDir" ] && mkdir "$tmpDir";
cd "$tmpDir";
currDir="$(pwd | egrep -ioe [0-9]+$)";
[ "$currDir" != "$tmpDir" ] && echo "failed to create and/or navigate to temporary directory" && exit 4;
i=0;
while read seg
	do
		wget -O "$i.ts" --continue "$seg";
		i=$((++i));
done <<< "$hlsPlaylist"

# determine if space is enough for appending and transcoding
freeSpace="$(df --output='avail' . | egrep -ioe '^[0-9]+')";
neededSpace="$((2*$(du -s . | egrep -ioe '^[0-9]+')))";
[ "$freeSpace" -lt "$neededSpace" ] && echo "free more space and run with -t $tmpDir" && exit 5;
segs=$(ls -v {0..9999}.ts 2> /dev/null);

while read seg
	do
		cat "$seg" >> file.ts && rm "$seg";
done <<< "$segs"

ffmpeg -i file.ts -c copy "$outputName" && rm file.ts;
mv "$outputName" ../;
cd ../;
rm -r "$tmpDir";
echo "video file saved as $outputName" && exit 0;