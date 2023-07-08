#!/bin/sh

usage=$(cat <<'EOF'
4shkin: a 4chan browser, in the terminal, in POSIX sh and coreutils ONLY
usage: 4shkin.sh [board (thread)] e.g:
    4shkin.sh g
    4shkin.sh g 12345678
Probably pipe into a pager for easier usage:
    4shkin.sh g 12345678 | less -R
EOF
)

if [ -z "$*" ]
then
	printf '%s\n' "No arguments given!"
	printf '%s\n' "$usage"
	exit
fi

for arg in $*
do
	case "$arg" in
		[a-zA-Z]*)	board="$arg" ;;
		[0-9]*)		thread="$arg" ;;
	esac
done

decode_shit() {
	printf '%s\n' "$*" | sed \
	-e 's/"//g' \
	-e 's/&quot;/"/g' \
	-e 's/&amp;/\&/g' \
	-e 's/&gt;/>/g' \
	-e "s/&#039;/'/g" \
	-e 's/<br>/\n/g' \
	-e 's/\\\//\//g' \
	-e 's/\\n/\n/g' \
	-e 's/<[^>]*>//g' \
	-e 's/}$//g'
}

print_box() {
	filename="$1"
	title="$2"
	author="$3"
	postid="$4"
	text="$5"
	image="$6"

	printf '+%*s+\n' 78 '' | tr ' ' '-'

	if [ -n "$title" ]
	then
		printf '|\033[4m%s\033[0m%*s|\n' "$title" $(( 78 - ${#title} )) ''
	fi

	printf '|%s' "$author"
	printf '\033[90m %-*s\033[0m|\n' $(( 77 - ${#author} )) "$postid"

	if [ -n "$filename" ]
	then
		printf '|%s' "[ $filename ]" 
		printf '%*s|\n' $(( 74 - ${#filename} )) '' | tr ' ' '-'
	else
		printf '+%*s+\n' 78 '' | tr ' ' '-'
	fi

	if [ -n "$filename" ]
	then
		printf '|%-*s|\n' 78 '+---------+'
		printf '|%-*s|\n' 78 '|         |'
		printf '|%-*s|\n' 78 '| I  M  G |'
		printf '|%-*s|\n' 78 '|         |'
		printf '|%-*s|\n' 78 '+---------+'
	fi


	text=$(prettify_text "$text")
	text=$(printf '%s' "$text" | fold -s -w 78)
	while IFS= read -r line
	do
		width=$( printf '%s' "$line" | grep -o $(printf '\033') | wc -l )
		width=$(( width * 5 ))
		width=$(( width + 78 ))
		printf '|%-*s|\n' "$width" "$line"
	done << EOF
$text
EOF
	printf '|%-*s+\n' 78 '' | tr ' ' '-'
	if [ -n "$image" ]
	then
		printf 'Image link: %s\n' "https://i.4cdn.org/$board/$image"
	fi
	printf '\n'
}

prettify_text() {
	text="$*"
	while IFS= read -r line
	do
		case "$line" in
			*'>>'"$thread"*)
				printf '%s\n' "$line" | sed -E -e 's/>>[0-9]+/'$(printf '\033[31m')'&(OP)'$(printf '\033[;0m')'/g' ;;
			*'>>'*)
				printf '%s\n' "$line" | sed -E -e 's/>>[0-9]+/'$(printf '\033[31m')'&'$(printf '\033[;0m')'/g' ;;
			*'>'*)
				printf '%s\n' "$line" | sed -e 's/>.*$/'$(printf '\033[32m')'&'$(printf '\033[;0m')'/g';;				
			*) printf '%s\n' "$line" ;;
		esac
	done << EOF
$text
EOF
}

json_parse() {
	raw=$(curl -s "$to_grab")
	error_text='alt="404 Not Found"'
	case "$raw" in
		'') # Because i use the cdn for threads and the main for boards, an empty thread is empty and an empty board is html
			printf 'Page not found. Thread may have fallen off\n'
			#printf '%s\n' "$raw"
			exit ;;
		*"$error_text"*)
			printf 'Board not found. Did you type it correctly?\n'
			#printf '%s\n' "$raw"
			exit ;;
	esac
	raw=$(printf '%s\n' "$raw" | sed -e 's/},\("[0-9]\|{"\)/}\n&/g' -e 's/{"posts":\[{//')
	printf '%s\n' "$raw" | while IFS= read -r reply
	do
		reply=$(printf '%s' "$reply" | sed -e 's/\(,\|:{\)"/\n"/g')
		#printf '%s\n' "$reply"
		unset reply_nmbr
		unset reply_text
		unset reply_extn
		unset reply_titl
		unset reply_name
		unset reply_file
		unset reply_imag

		while IFS= read -r line
		do
			case "$line" in
				*'no"'*|'"'[0-9]*'"')		reply_nmbr=$(decode_shit "${line#*:}") ;; # Not super necessary but nice
				'"com"'*)		reply_text=$(decode_shit "${line#*:}") ;;
				'"teaser"'*)	reply_text=$(decode_shit "${line#*:}" | cut -c -156)"..." ;;
				'"ext"'*)		reply_extn=$(decode_shit "${line#*:}") ;;
				'"sub"'*)		reply_titl=$(decode_shit "${line#*:}") ;;
				'"name"'*|'"author"'*)		reply_name=$(decode_shit "${line#*:}") ;;
			'"filename"'*|'"file"'*)	reply_file=$(decode_shit "${line#*:}") ;;
			'"tim"'*)		reply_imag="${line#*:}$reply_extn" ;;
			esac
		done << EOF
$reply
EOF
		print_box "$reply_file$reply_extn" "$reply_titl" "$reply_name" "$reply_nmbr" "$reply_text" "$reply_imag"
	done
}

if [ -n "$board" ] && [ -n "$thread" ]
then
	printf 'Loading thread %s on board /%s/\n' "$thread" "$board" 1>&2
	to_grab='https://a.4cdn.org/'$board'/thread/'$thread'.json'
elif [ -n "$board" ]
then
	printf 'Loading board - /%s/\n' "$board" 1>&2
	to_grab='https://boards.4channel.org/'$board'/catalog'
else
	printf 'No board specified!'
	exit
fi

#printf '%s' "$(json_parse)" # So it all displays at once
json_parse
