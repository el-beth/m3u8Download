#!/bin/bash

# there are two types of m3u8 manifests,
# the first avails the HLS player of the various resolution/data-rate streams on offer -- this type is called the multivariant index
# the second avails a series of .ts segments that are playbacked by the HLS player
# as for the manifest content lines, they could complete absolute paths (a Fully Qualified domain and path) pointing to the resources,

url=`egrep -ioe '^https?:\/\/.+$' <<< "$1"`;
page="";
indexClass="";
multivarChoice="";
[ -z "$url" ] && echo "[error]: the calling string is not a valid http or https URL" && exit 1;
function fetch(){
	page=`wget -q -O - "$1"`;
	[ -z "$page" ] && echo "[error]: error encountered when fetching the html for $1" && exit 1;
}

function classifyIndexFile(){
	(egrep -qie '\#EXT-X-STREAM-INF *: *(PROGRAM-ID=[0-9]+|BANDWIDTH=([^,]+)|RESOLUTION=([0-9]+x[0-9]+)|CODECS="([^"]+)"|FRAME-RATE=([0-9\.])+|,)+' <<< "$page" && indexClass="multivar") || indexClass="segments"
}



fetch;
classifyIndexFile;
case "$indexClass" in
	"multivar" )
		echo  "[info]: the index file is a multivariant index";
		echo "[input]: choose a variant:";
		i=1;
		while read choice;
			do
				echo "$i: $choice";
				i=$((++i));
		done <<< `egrep -ioe '\#EXT-X-STREAM-INF *: *(PROGRAM-ID=([0-9]+)|BANDWIDTH=([^,]+)|RESOLUTION=([0-9]+x[0-9]+)|CODECS="([^"]+)"|FRAME-RATE=([0-9\.]+)|,)+' <<< "$page" | sed -Ee 's/\#EXT-X-STREAM-INF *: *(PROGRAM-ID=([0-9]+)|BANDWIDTH=([^,]+)|RESOLUTION=([0-9]+x[0-9]+)|CODECS="([^"]+)"|FRAME-RATE=([0-9\.]+)|,)+/Resolution: \4, CoDecs: \5, Framerate: \6/gi'`
		read -N 1 multivarChoice;
		while ( ! egrep -qe '^[0-9]$' <<< "$multivarChoice" )
		do
			echo "[inputError]: input only a single number"
			read -N 1 multivarChoice;
		done
		var=$(egrep -ioe '\#EXT-X-STREAM-INF *: *(PROGRAM-ID=([0-9]+)|BANDWIDTH=([^,]+)|RESOLUTION=([0-9]+x[0-9]+)|CODECS="([^"]+)"|FRAME-RATE=([0-9\.]+)|,)+' <<< "$page" | sed -n "${multivarChoice}p")
		;;
		selectionUrl=`pcregrep -M "${var}\n.+" <<< "$page" | tail -n 1`
		egrep -qie '^https?:\/\/.+$' <<< "$selectionUrl" || selectionUrl="$(sed -Ee 's/^(.+\/).+?$/\1/gi' <<< "$url")$selectionUrl"
	"segments" )
		echo  "the index file is a segments index"
		;;
esac