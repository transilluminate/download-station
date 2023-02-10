#!/bin/bash
# Copyright 2023 Adrian Robinson <adrian.j.robinson at gmail dot com>
# https://github.com/transilluminate/download-station

# Inspiration and a couple of lines from the now non-functional ds-cli script
# https://github.com/xaozai/ds-cli

# location of the config file
CONFIG_FILE="/var/services/homes/adrian/etc/download-station.config"

# set to 0 for quiet, 1 for progress, 2 for JSON responses
DEBUG_LEVEL=0

# our wget parameters
WGET="wget --no-check-certificate -qO -"

# load external config file for login details
if [ -e $CONFIG_FILE ]; then
	source $CONFIG_FILE
else
	echo "Config file does not exist!"
	echo "Please see download-station.config.example for hints"
	exit 1
fi

setup_colours() {
	# Check if terminal allows output, if yes, define colors for output
	if [[ -t 1 ]]; then
		RED="\033[1;31m"
		GREEN="\033[1;32m"
		NC="\033[0m"		# (N)o (C)olour
	else
		RED=''; GREEN=''; NC='';
	fi
}

check_tool() {
	# https://stackoverflow.com/questions/7522712/how-can-i-check-if-a-command-exists-in-a-shell-script
	local command=$1
	if ! command -v "$command" >/dev/null; then
		if [[ $DEBUG_LEVEL -gt 0 ]]; then
			echo -e "${RED}Error, command '$command' could not be found!${NC}"
		fi
		exit 1
	fi
}

init() {
	setup_colours
	if [[ $DEBUG_LEVEL -gt 0 ]]; then echo -n "Initialising environment... "; fi
	check_tool jq
	check_tool wget
	check_tool base64
	check_tool numfmt
	if [[ $DEBUG_LEVEL -gt 0 ]]; then echo -e "${GREEN}OK${NC}"; fi
	check_API
	get_SID
}

check_response() {
	local response=$1
	if [[ $(echo "$response" | jq -r '.success') != 'true' ]]; then
		error_code=$(echo "$response" | jq -r '.error.code')
		echo $error_code
	else
		echo 0
	fi
}

error_description () {	# who puts non-unique error codes?!
	local error_code=$1
	local API=$2
	# common error codes
	if [[ $error_code == "100" ]]; then echo "=> Unknown error"; fi
	if [[ $error_code == "101" ]]; then echo "=> Invalid parameter"; fi
	if [[ $error_code == "102" ]]; then echo "=> The requested API does not exist"; fi
	if [[ $error_code == "103" ]]; then echo "=> The requested method does not exist"; fi
	if [[ $error_code == "104" ]]; then echo "=> The requested version does not support the functionality"; fi
	if [[ $error_code == "105" ]]; then echo "=> The logged in session does not have permission"; fi
	if [[ $error_code == "106" ]]; then echo "=> Session timeout"; fi
	if [[ $error_code == "107" ]]; then echo "=> Session interrupted by duplicate login"; fi
	
	if [[ $API == "SYNO.API.Auth" ]]; then
		if [[ $error_code == "400" ]]; then echo "=> No such account or incorrect password"; fi
		if [[ $error_code == "401" ]]; then echo "=> Account disabled"; fi
		if [[ $error_code == "402" ]]; then echo "=> Permission denied"; fi
		if [[ $error_code == "403" ]]; then echo "=> 2-step verification code required"; fi
		if [[ $error_code == "404" ]]; then echo "=> Failed to authenticate 2-step verification code"; fi
		
	elif [[ $API == "SYNO.DownloadStation.Task" ]]; then
		if [[ $error_code == "400" ]]; then echo "=> File upload failed"; fi
		if [[ $error_code == "401" ]]; then echo "=> Max number of tasks reached"; fi
		if [[ $error_code == "402" ]]; then echo "=> Destination denied"; fi
		if [[ $error_code == "403" ]]; then echo "=> Destination does not exist"; fi
		if [[ $error_code == "404" ]]; then echo "=> Invalid task id"; fi		
		if [[ $error_code == "405" ]]; then echo "=> Invalid task action"; fi		
		if [[ $error_code == "406" ]]; then echo "=> No default destination"; fi
		if [[ $error_code == "407" ]]; then echo "=> Set destination failed"; fi
		if [[ $error_code == "408" ]]; then echo "=> File does not exist"; fi			
	fi
}

check_API() {
	if [[ $DEBUG_LEVEL -gt 0 ]]; then echo -n "Checking API on Synology... "; fi
	local API="SYNO.API.Info"
	# /webapi/query.cgi is the only 'fixed' URL in the API
	local response=$($WGET "${LOCATION}/webapi/query.cgi?api=${API}&version=1&method=query&query=SYNO.API.Auth,SYNO.DownloadStation.Task")
	if [[ $(echo "$response" | jq -r '.success') != 'true' ]]; then
		local error_code=$(echo "$response" | jq -r '.error.code')
		if [[ $DEBUG_LEVEL -gt 0 ]]; then
			echo -e "${RED}Error code: $error_code ${NC}"
			echo $( error_description $error_code $API )
		fi
		if [[ $DEBUG_LEVEL -gt 1 ]]; then echo "$response" | jq -r '.'; fi
		exit 1
	else
		Auth_URL=$(echo "$response" | jq -r '.data."SYNO.API.Auth".path')
		DS_URL=$(echo "$response" | jq -r '.data."SYNO.DownloadStation.Task".path')
		if [[ $DEBUG_LEVEL -gt 0 ]]; then
			echo -e "${GREEN}OK!${NC}"
			echo "=> Auth_URL: /webapi/$Auth_URL"
			echo "=> DS_URL:   /webapi/$DS_URL"
		fi
		if [[ $DEBUG_LEVEL -gt 1 ]]; then echo "$response" | jq -r '.'; fi
	fi
}

get_SID() {
	if [[ $DEBUG_LEVEL -gt 0 ]]; then echo -n "Getting authentication token... "; fi
	local API="SYNO.API.Auth"
	local response=$($WGET "${LOCATION}/webapi/${Auth_URL}?api=${API}&version=3&method=login&account=${USERNAME}&passwd=${PASSWORD}&session=DownloadStation&format=sid")	
	if [[ $(echo "$response" | jq -r '.success') != 'true' ]]; then
		local error_code=$(echo "$response" | jq -r '.error.code')
		if [[ $DEBUG_LEVEL -gt 0 ]]; then
			echo -e "${RED}Error code: $error_code ${NC}"
			echo $( error_description $error_code $API )
		fi
		if [[ $DEBUG_LEVEL -gt 1 ]]; then echo "$response" | jq -r '.'; fi
		exit 1
	else
 		SID=$(echo "$response" | jq -r '.data.sid')
		if [[ $DEBUG_LEVEL -gt 0 ]]; then
			echo -e "${GREEN}OK!${NC}"
			echo "=> SID: ${SID}"
		fi
		if [[ $DEBUG_LEVEL -gt 1 ]]; then echo "$response" | jq -r '.'; fi		
	fi
}

clean_up() {
	if [[ $DEBUG_LEVEL -gt 0 ]]; then echo -n "Cleaning up... "; fi
	local API="SYNO.API.Auth"	
	local response=$($WGET "${LOCATION}/webapi/${Auth_URL}?api=${API}&version=3&method=logout&session=DownloadStation")
	if [[ $(echo "$response" | jq -r '.success') != 'true' ]]; then
		local error_code=$(echo "$response" | jq -r '.error.code')
		if [[ $DEBUG_LEVEL -gt 0 ]]; then
			echo -e "${RED}Error code: $error_code ${NC}"
			echo $( error_description $error_code $API )
		fi
		if [[ $DEBUG_LEVEL -gt 1 ]]; then echo "$response" | jq -r '.'; fi
		exit 1
	else
		if [[ $DEBUG_LEVEL -gt 0 ]]; then echo -e "${GREEN}OK!${NC}"; fi
		if [[ $DEBUG_LEVEL -gt 1 ]]; then echo "$response" | jq -r '.'; fi		
	fi
}

list() {
	if [[ $DEBUG_LEVEL -gt 0 ]]; then echo -n "Getting download tasks... "; fi
	local API="SYNO.DownloadStation.Task"
	local response=$($WGET "${LOCATION}/webapi/${DS_URL}?api=${API}&version=1&method=list&additional=transfer&_sid=${SID}")
	if [[ $(echo "$response" | jq -r '.success') != 'true' ]]; then
		local error_code=$(echo "$response" | jq -r '.error.code')
		if [[ $DEBUG_LEVEL -gt 0 ]]; then
			echo -e "${RED}Error code: $error_code ${NC}"
			echo $( error_description $error_code $API )
		fi
		if [[ $DEBUG_LEVEL -gt 1 ]]; then echo "$response" | jq -r '.'; fi
		exit 1
	else
		if [[ $DEBUG_LEVEL -gt 0 ]]; then echo -e "${GREEN}OK!${NC}"; fi
		tasks=$(echo "$response" | jq -r '.data.total')
		if [[ $DEBUG_LEVEL -gt 0 ]]; then
			echo "=> Number of downloads: $tasks"
			echo "=> Format: id,\"title\",status,download speed,downloaded,size,percentage complete"
		fi
		if [[ $tasks -gt 0 ]]; then
			# base64 packing/unpacking from https://github.com/xaozai/ds-cli
			for row in $(echo "$response" | jq -r '.data.tasks[] | @base64'); do
			    decode_json() { echo ${row} | base64 --decode | jq -r ${1}; }
			    id=$(decode_json '.id')
			    title=$(decode_json '.title')
			    status=$(decode_json '.status')
			    speed=$(decode_json '.additional.transfer.speed_download')
			    speed_human="$(numfmt --to=iec $speed)B/s"
			    size=$(decode_json '.size')
			    size_human="$(numfmt --to=iec $size)B"
			    downloaded=$(decode_json '.additional.transfer.size_downloaded')
			    downloaded_human="$(numfmt --to=iec $downloaded)B"
			    if [[ $size -ne 0 ]]; then	# avoid divide by zero
			    	percent=$(awk -v a=$downloaded -v b=$size 'BEGIN{printf("%.1f%%", (a/b)*100)}')
			    else
			    	percent="0%"
			    fi
			    if [[ $DEBUG_LEVEL -gt 0 ]]; then echo -n "=> "; fi
			    echo -e "${GREEN}$id,\"$title\",$status,$speed_human,$downloaded_human,$size_human,$percent${NC}"
			done
		fi
		if [[ $DEBUG_LEVEL -gt 1 ]]; then echo "$response" | jq -r '.'; fi
	fi
}

add() {
	if echo "$1" | grep -m 1 -q "magnet:?\|^http://.*\.torrent$\|^https://.*\.torrent$"; then
		echo -n "Adding URL... "
		local API="SYNO.DownloadStation.Task"
		local cleaned_url=$(echo -n "$1" | sed -e 's/%/%25/g' | sed -e 's/+/%2B/g'  | sed -e 's/ /%20/g' | sed -e 's/&/%26/g'  | sed -e 's/=/%3D/g')
		local response=$($WGET "${LOCATION}/webapi/${DS_URL}?api=${API}&version=2&method=create&uri=${cleaned_url}&_sid=${SID}")
		if [[ $(echo "$response" | jq -r '.success') != 'true' ]]; then
			local error_code=$(echo "$response" | jq -r '.error.code')
			echo -e "${RED}Error code: $error_code ${NC}"			
			if [[ $DEBUG_LEVEL -gt 0 ]]; then echo $( error_description $error_code $API ); fi
			if [[ $DEBUG_LEVEL -gt 1 ]]; then echo "$response" | jq -r '.'; fi	
			exit 1
		else
			echo -e "${GREEN}OK!${NC}"
			if [[ $DEBUG_LEVEL -gt 1 ]]; then echo "$response" | jq -r '.'; fi
		fi
	else
		echo -e "Adding URL... ${RED}Error, invalid URL${NC}"
	fi
}

action() {
	action=$1
	id=$2
	if [[ $action == "pause" ]]; 	then echo -n "Pausing task '${id}'... "; fi
	if [[ $action == "resume" ]];	then echo -n "Resuming task '${id}'... "; fi
	if [[ $action == "delete" ]];	then echo -n "Deleting task '${id}'... "; fi
	local API="SYNO.DownloadStation.Task"
	local response=$($WGET "${LOCATION}/webapi/${DS_URL}?api=${API}&version=1&method=${action}&id=${id}&_sid=${SID}")
	if [[ $(echo "$response" | jq -r '.success') != 'true' ]]; then
		local error_code=$(echo "$response" | jq -r '.error.code')
		echo -e "${RED}Error code: $error_code ${NC}"
		if [[ $DEBUG_LEVEL -gt 0 ]]; then echo $( error_description $error_code $API ); fi
		if [[ $DEBUG_LEVEL -gt 1 ]]; then echo "$response" | jq -r '.'; fi
		exit 1
	else
		echo -e "${GREEN}OK!${NC}"
		if [[ $DEBUG_LEVEL -gt 1 ]]; then echo "$response" | jq -r '.'; fi		
	fi
}

case "${1}" in
	list)
		init
		list
		clean_up
	;;
	add)
		init
		add "${2}"
		clean_up
	;;
	delete)
		init
		action delete "${2}"
		clean_up	
	;;
	pause)
		init
		action pause "${2}"
		clean_up	
	;;
	resume)
		init
		action resume "${2}"
		clean_up
	;;	
	*)
    echo "Usage: $0 [options]"
    echo "Options are:"
    echo "  list        - lists current downloads"
    echo "  add <url>   - adds the .torrent or magnet link"
    echo "  delete <id> - deletes the download"
    echo "  pause <id>  - pauses the download"
    echo "  resume <id> - resumes the download"
    exit 1
    ;;
esac
exit 0
