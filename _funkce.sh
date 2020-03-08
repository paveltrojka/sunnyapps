#!/bin/bash


#  __   __    _     ___   ___ 
#  \ \ / /   /_\   | _ \ / __|
#   \ V /   / _ \  |   / \__ \
#    \_/   /_/ \_\ |_|_\ |___/

run_dir=$(dirname "${BASH_SOURCE[0]}")

FILE=$run_dir/_vars_dir ; [[ -f $FILE ]] && source $FILE || echo "$FILE not loaded"
[[ `ls $MAINSHARE12/_vars_* | grep -v "^_vars_dir$" | wc -l` -gt 0 ]] && for i in `ls $MAINSHARE12/_vars* | grep -v "^_vars_dir$"` ; do source "$i" ; done
[[ `ls $MAINSHAREID/*.load` ]] 2>/dev/null &&  for i in $MAINSHAREID/*.load ; do source $i ; done
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




