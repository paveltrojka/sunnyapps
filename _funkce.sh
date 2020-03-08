#!/bin/bash


#  __   __    _     ___   ___ 
#  \ \ / /   /_\   | _ \ / __|
#   \ V /   / _ \  |   / \__ \
#    \_/   /_/ \_\ |_|_\ |___/

run_dir=$(dirname "${BASH_SOURCE[0]}")

FILE=$run_dir/_vars_dir 		; [[ -f $FILE ]] && source $FILE || echo "$FILE not loaded"
FILE=$MAINSHARE12/_vars_host 	; [[ -f $FILE ]] && source $FILE || echo "$FILE not loaded"
FILE=$MAINSHARE12/_vars_dir2 	; [[ -f $FILE ]] && source $FILE || echo "$FILE not loaded"
FILE=$MAINSHARE12/_vars_url 	; [[ -f $FILE ]] && source $FILE || echo "$FILE not loaded"
FILE=$MAINSHARE12/_vars_sw 		; [[ -f $FILE ]] && source $FILE || echo "$FILE not loaded"
FILE=$MAINSHARE12/_vars_other 	; [[ -f $FILE ]] && source $FILE || echo "$FILE not loaded"

FILE=$MAINSHARE12/_vars_daily_quote	; [[ -f $FILE ]] && source $FILE || echo "$FILE not loaded"



# credence

for i in $MAINSHAREID/*.load ; do source $i ; done
FILE=$MAINSHAREID/credence.conf ; [[ -f $FILE ]] && source $FILE || echo "$FILE not loaded"


#   ___   _   _   _  _   _  __   ___   ___ 
#  | __| | | | | | \| | | |/ /  / __| | __|
#  | _|  | |_| | | .` | | ' <  | (__  | _| 
#  |_|    \___/  |_|\_| |_|\_\  \___| |___|







for i in $MAINSHARE12/_funkce_*.sh ; do 
	# printf "\nsourcing $i .... " 
	source "$i"
	[[ ! `source $i` == "" ]] && echo "$?" && echo "chyba"
done	












