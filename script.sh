#!/bin/bash

# call as ./script.sh <M3U8 playlist URL>
# this script relies upon pcregrep - one that supports multiline regular expressions
# 1. get the playlist
page="$(wget -O - "$1")";

