#!/bin/bash

# there are two types of m3u8 manifests,
# the first avails the HLS player of the various resolution/data-rate streams on offer -- this type is called the multivariant index
# the second avails a series of .ts segments that are playbacked by the HLS player
# as for the manifest content lines, they could complete absolute paths (a Fully Qualified domain and path) pointing to the resources,

# TODO: help syntax output
# TODO: Use ETag for the m3u8 as a session identifier, then fall back to md5sum of the first TS segment file, and only use $RANDOM as a last resort if no identifier can be found in the HTTP reply headers.
# TODO: doing the above to make continuing a download possible.

arguments="$@";
function showHelp(){
	if ( egrep -qe '( *-h| *--help)' <<< "${arguments}" )
	then
		# help message goes here
		echo -e "\nSYNTAX:\n\tscript.sh [OPTION]... [URL]\n\nThe script must be called with an output name\n\n\t-o,  --output=FILE         the stream will be saved to FILE\n\t-h,  --help                show this help message and exit" && exit 0;
	fi
}
showHelp;


url=`egrep -ioe 'https?:\/\/[^ ]+' <<< "${arguments}"`;
urlBase=`sed -Ee 's/^(.+\/).+?$/\1/gi' <<< "$url"`;
([ -z "$urlBase" ] || [ -z "$url" ]) && echo "[error]: malformed URL" && exit 1;
page="";
indexClass="";
multivarChoice="";
segmentsFile="";
SID="$RANDOM";


function argumentParse(){
	# SYNTAX:
	# argumentParse '-o' '--output'; 
	# $1 must be the short form of the argument flag
	# $2 must be the long form of the argument flag
	# both argument flags are necessary
	# if the flag gets repeated, only the first argument of either the short form or long form is returned
	flagShort="$(egrep -ioe '^-[a-z0-9]$' <<< "$1")";
	flagLong="$(egrep -ioe '^--[a-z0-9]{2,}$' <<< "$2")";
	if ( [ -z "${flagShort}" ] || [ -z "${flagLong}" ] )
	then
		echo -e "[error]: argumentParse SYNTAX:\n\n\targumentParse -o --outout\n" && return 1;
	fi
	argument="$(egrep -ioe "(${flagLong}[ =]|${flagShort} +)(.+?)( +-[a-z0-9] *.*$| +--[a-z0-9]{2,}.*$|https?:\/\/[^ ]+.*$|$)" <<< "${arguments}" | sed -Ee "s/(${flagLong}[ =]|${flagShort} +)(.+?)( +-[a-z0-9] *.*$| +--[a-z0-9]{2,}.*$|https?:\/\/[^ ]+.*$)/\2/gi" -e "s/^(${flagLong}[ =]|$flagShort +)//g")";	
	if [ -z "${argument}" ]
	then
		echo "[error]: problem extracting argument for flag ${flagShort}, ${flagLong}" && return 2;
	else
		echo "${argument}";
		return 0;
	fi
}
outputName="$(argumentParse -o --output)";
[ $? != "0" ] && echo "[error]: \$outputName is empty, add -o OUTPUTNAME or --output OUTPUTNAME when calling the script" && exit;

if [ -f "${outputName}" ]
then
	echo "[error]: the filename '${outputName}' is already in use" && exit 1;
fi
echo "[info]: the file will be saved as '${outputName}'";

[ -z "$url" ] && echo "[error]: the calling string is not a valid http or https URL" && exit 1;
function fetch(){
	page=`wget --timeout=30 -q -O - "$url"`;
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
			echo "[info]: index file is multivariant manifest"
			echo "[info]: the index file is a multivariant index";
			echo "[input]: choose a variant:";
			i=1;
			while read choice;
				do
					echo "$i: $choice";
					i=$((++i));
			done <<< `egrep -ioe '\#EXT-X-STREAM-INF *: *(PROGRAM-ID=([0-9]+)|BANDWIDTH=([^,]+)|RESOLUTION=([0-9]+x[0-9]+)|CODECS="([^"]+)"|FRAME-RATE=([0-9\.]+)| *, *)+' <<< "$page" | sed -Ee 's/\#EXT-X-STREAM-INF *: *//gi'`;
			read -N 1 multivarChoice;
			while ( ! egrep -qe '^[0-9]$' <<< "$multivarChoice" )
			do
				echo "[inputError]: input only a single number";
				read -N 1 multivarChoice;
			done
			var=$(egrep -ioe '\#EXT-X-STREAM-INF *: *(PROGRAM-ID=([0-9]+)|BANDWIDTH=([^,]+)|RESOLUTION=([0-9]+x[0-9]+)|CODECS="([^"]+)"|FRAME-RATE=([0-9\.]+)|,|.+)+' <<< "$page" | sed -n "${multivarChoice}p");
			selectionUrl=`pcregrep -M "${var}\n.+" <<< "$page" | tail -n 1`;
			egrep -qie '^https?:\/\/.+$' <<< "$selectionUrl" || selectionUrl="${urlBase}${selectionUrl}";
			urlBase=`sed -Ee 's/^(.+\/).+?$/\1/gi' <<< "$selectionUrl"`;
			segmentsFile=`wget --timeout=30 -q -O - "$selectionUrl"`;
			i=1;
			if [ -f ${SID}_temp.vid ];
				then 
					rm ${SID}_temp.vid;
			fi
			while read segmentUrl;
			do
				if (! egrep -qe '^https?://.+' <<< "$segmentUrl")
					then
						if (wget --timeout=30 -q -O - "${urlBase}${segmentUrl}" >> ${SID}_temp.vid);
							then
								echo "[info]: got segment $i";
							else
								echo "${urlBase}${segmentUrl}";
								echo "[exit]: fatal error when downloading segment $i" && exit 1
						fi
					else
						if (wget --timeout=30 -q -O - "$segmentUrl" >> ${SID}_temp.vid);
							then
								echo "[info]: got segment $i";
							else
								echo "[exit]: fatal error when downloading segment $i" && exit 1
						fi
				fi
				i=$((++i));
			done <<< `egrep -ve '^\#.+' <<< $segmentsFile`;
			[ -f ${SID}_temp.vid ] && ffmpeg -i ${SID}_temp.vid -c copy "$outputName" &> /dev/null && rm ${SID}_temp.vid && echo "[success]: completed the download, file name $outputName" && return 0;
			;;
		"segments" )
			echo "[info]: index file is TS segment manifest"
			selectionUrl=$url;
			segmentsFile=`wget --timeout=30 -q -O - "$selectionUrl"`;
			i=1;
			if [ -f ${SID}_temp.vid ];
				then
					rm ${SID}_temp.vid;
			fi
			
			while read segmentUrl;
			do
				if (! egrep -qe '^https?://.+' <<< "$segmentUrl")
					then
						if (wget --timeout=30 -q -O - "${urlBase}${segmentUrl}" >> ${SID}_temp.vid);
							then
								echo "[info]: got segment $i";
							else
								echo "[exit]: fatal error when downloading segment $i" && exit 1
						fi
					else
						if (wget --timeout=30 -q -O - "$segmentUrl" >> ${SID}_temp.vid);
							then
								echo "[info]: got segment $i";
							else
								echo "[exit]: fatal error when downloading segment $i" && exit 1
						fi
				fi
				i=$((++i));
			done <<< `egrep -ve '^\#.+' <<< $segmentsFile`;
			[ -f ${SID}_temp.vid ] && ffmpeg -i ${SID}_temp.vid -c copy "$outputName" &> /dev/null && rm ${SID}_temp.vid && echo "[success]: completed the download, file name $outputName" && return 0;
			;;
	esac
}

fetch;
classifyIndexFile;
processIndex;