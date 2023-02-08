#!/bin/bash

# there are two types of m3u8 manifests,
# the first avails the HLS player of the various resolution/data-rate streams on offer -- this type is called the multivariant index
# the second avails a series of .ts segments that are playbacked by the HLS player
# as for the manifest content lines, they could complete absolute paths (a Fully Qualified domain and path) pointing to the resources,

url=`egrep -ioe 'https?:\/\/[^ ]+' <<< "$@"`;
urlBase=`sed -Ee 's/^(.+\/).+?$/\1/gi' <<< "$url"`;
page="";
indexClass="";
multivarChoice="";
segmentsFile="";
outputName=`egrep -ioe '(-o|--output)(=| )?([^ ]+)' <<< "$@" | sed -Ee 's/(-o|--output)(=| )?([^ ]+)/\3/gi';`
[ -z "$url" ] && echo "[error]: the calling string is not a valid http or https URL" && exit 1;
function fetch(){
	page=`wget -q -O - "$url"`;
	[ -z "$page" ] && echo "[error]: error encountered when fetching the html for $1" && exit 1;
}

function classifyIndexFile(){
	if (egrep -qie '\#EXT-X-STREAM-INF *: *(PROGRAM-ID=[0-9]+|BANDWIDTH=([^,]+)|RESOLUTION=([0-9]+x[0-9]+)|CODECS="([^"]+)"|FRAME-RATE=([0-9\.])+|,)+' <<< "$page"); 
		then indexClass="multivar";
		else indexClass="segments";
	fi
}

function processIndex(){
	case "$indexClass" in
		"multivar" )
			echo "[info]: the index file is a multivariant index";
			echo "[input]: choose a variant:";
			i=1;
			while read choice;
				do
					echo "$i: $choice";
					i=$((++i));
			done <<< `egrep -ioe '\#EXT-X-STREAM-INF *: *(PROGRAM-ID=([0-9]+)|BANDWIDTH=([^,]+)|RESOLUTION=([0-9]+x[0-9]+)|CODECS="([^"]+)"|FRAME-RATE=([0-9\.]+)|,)+' <<< "$page" | sed -Ee 's/\#EXT-X-STREAM-INF *: *(PROGRAM-ID=([0-9]+)|BANDWIDTH=([^,]+)|RESOLUTION=([0-9]+x[0-9]+)|CODECS="([^"]+)"|FRAME-RATE=([0-9\.]+)|,)+/Resolution: \4, CoDecs: \5, Framerate: \6/gi'`;
			read -N 1 multivarChoice;
			while ( ! egrep -qe '^[0-9]$' <<< "$multivarChoice" )
			do
				echo "[inputError]: input only a single number";
				read -N 1 multivarChoice;
			done
			var=$(egrep -ioe '\#EXT-X-STREAM-INF *: *(PROGRAM-ID=([0-9]+)|BANDWIDTH=([^,]+)|RESOLUTION=([0-9]+x[0-9]+)|CODECS="([^"]+)"|FRAME-RATE=([0-9\.]+)|,)+' <<< "$page" | sed -n "${multivarChoice}p");
			selectionUrl=`pcregrep -M "${var}\n.+" <<< "$page" | tail -n 1`;
			egrep -qie '^https?:\/\/.+$' <<< "$selectionUrl" || selectionUrl="${urlBase}${selectionUrl}";
			segmentsFile=`wget -q -O - "$selectionUrl"`;
			i=1;
			if [ -f temp.vid ];
				then 
					rm temp.vid;
			fi

			while read segmentUrl;
			do
				if (wget -q -O - "${urlBase}${segmentUrl}" >> temp.vid);
					then
						echo "[info]: got segment $i";
					else
						echo "[exit]: fatal error when downloading segment $i" && exit 1
				fi
				i=$((++i));
			done <<< `egrep -ve '^\#.+' <<< $segmentsFile`;
			[ -f temp.vid ] && mv temp.vid "$outputName" && echo "[success]: completed the download, file name $outputName"
			;;
		"segments" )
			selectionUrl=$url;
			segmentsFile=`wget -q -O - "$selectionUrl"`;
			i=1;
			if [ -f temp.vid ];
				then
					rm temp.vid;
			fi

			while read segmentUrl;
			do
				if (wget -q -O - "${urlBase}${segmentUrl}" >> temp.vid);
					then
						echo "[info]: got segment $i";
					else
						echo "[exit]: fatal error when downloading segment $i" && exit 1
				fi
				i=$((++i));
			done <<< `egrep -ve '^\#.+' <<< $segmentsFile`;
			mv temp.vid "$outputName" && echo "[success]: completed the download, file name $outputName"
			;;
	esac
}

fetch;
classifyIndexFile;
processIndex;