#!/bin/bash

# spusti vsechny vypocty
function CSV_UBER_MAIN {
	if [[ $1 == "--help" ]]  ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}  
	     "
	     return
	fi

	CSV_UPRAV_VSECHNY_CSV_V_ADRESARI
	CSV_SPOLECNY_HEADER_ALL

	CSV_KONVERZE_CELEHO_ADRESARE
	CSV_MERGE_NEWS
	CSV_NAJDI_A_SMAZ_DUPLICITY csv.merge
	CSV_EXPANDUJ_CAS csv.uniq

	# MINA - pozor vstupni soubor vetsi nez 2M zhrouti buffer a prestane doplnovat 
}

# vypise statistiku dle roku
function CSV_UBER_STATISTIKA {
	if [[ $1 == "--help" ]] || ([[  -z $2 ]] && [[ -z $souborCSV ]] )  ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}  <rok> <soubor.final>"
	     return
	fi

	local rok=$1
	[[ ! -z $2 ]] && local souborCSV=$2


	for i in {0..11} ; do 	# mesice
		aktualniMesic=${mesiceVRoce[$i]}
		echo 
		echocyan "------------------$aktualniMesic $rok-----------------------"
		echoboldred "[s.r.o.]"
		echo "Trzba Uberu ........ "
		echo "Poplatek Uberu ..... "`CSV_UBER_SOUCET Poplatek_Uberu $aktualniMesic $rok $souborCSV`
		echo "Vydelano ........... "`CSV_UBER_SOUCET Celkem $aktualniMesic $rok $souborCSV`
		echo "       .. z toho cash ....."
		echo "       .. z toho na ucet .."
		echo

		CSV_UBER_ZJISTI_RIDICE $aktualniMesic $rok "$souborCSV"
		echo "$ridiciVDanyMesic" | while IFS= read -r line ; do
			echoboldred "[$line]"
			echo "Trzba Uberu ........ "
			echo "Poplatek Uberu ..... "`CSV_UBER_SOUCET_PER_USER Poplatek_Uberu $aktualniMesic $rok "$line" "$souborCSV"`
			echo "Vydelano ........... "`CSV_UBER_SOUCET_PER_USER Celkem $aktualniMesic $rok "$line" "$souborCSV"`
			echo "       .. z toho cash ....."
			echo "       .. z toho na ucet .."
			echo

		done		


	done
}




function CSV_KTERY_SLOUPEC {
	value="$1"

	#pokud neni nactena promenna headerSpolecnyHodnotySloupcuVRadku , spust pomalou funkci, ktera ji vytvori
	[[ `echo $headerSpolecnyHodnotySloupcuVRadku` ]] || CSV_SPOLECNY_HEADER_ALL 

	eval "declare -a headerSpolecnyPoleHodnot=( $headerSpolecnyHodnotySloupcuVRadku )"
	for k in "${!headerSpolecnyPoleHodnot[@]}"; do
   		[[ "${headerSpolecnyPoleHodnot[$k]}" = "${value}" ]] && break
	done

	echo $((k+1))
}

function CSV_KTERY_SLOUPEC2 {
	if [[ $1 == "--help" ]] || [[ -z $1 ]] || ([[ -z $2 ]] && [[ -z $souborCSV ]] ) ; then 
         echo -e "Usage :   ${FUNCNAME[0]}  <nadpis sloupce> <file.csv>
         \rvraci poziceSloupce - integer"
         return
    fi

    local hledanyNadpis="$1"
    [[ ! -z $2 ]] && local souborCSV=$2

    poziceSloupce=`head -n 1 $souborCSV | tr ';' '\n' | awk "/$hledanyNadpis/ {print NR}"`
    echo "$poziceSloupce"   
}

function CSV_KTERY_SLOUPEC_VE_FINAL {
	if [[ $1 == "--help" ]] || ([[  -z $1 ]] && [[ -z $souborCSV ]] ) ; then 
	     echo -e "Usage :   ${FUNCNAME[0]} <value> <file.csv> 
	     "
	     return
	fi

	[[ ! -z $2 ]] && local souborCSV=$2
	value="$1"

	headerSpolecnyHodnotySloupcuVRadkuFinal=`head -n 1 $souborCSV | tr ";" " "`

	eval "declare -a headerSpolecnyPoleHodnotFinal=( $headerSpolecnyHodnotySloupcuVRadkuFinal )"
	for k in "${!headerSpolecnyPoleHodnotFinal[@]}"; do
   		[[ "${headerSpolecnyPoleHodnotFinal[$k]}" = "${value}" ]] && break
	done

	echo $((k+1))
}

function CSV_UPRAV_VSECHNY_CSV_V_ADRESARI {
	if [[ $1 == "--help" ]] ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}  
	     \rupravi vsehcny CSV v adresari"
	     return
	fi

	# uprav jmeno - smaz zavorky
	for t in *.csv ; do      
		mv "$t" `echo "$t" | tr -d '(' | tr -d ')' | tr -d ' '` 
	done > /dev/null 2>&1

	# uprav obsah
	for j53 in *.csv; do 
		CSV_COMMA_TO_SEMICOLON_UBER "$j53"
		TEXT_STRIP_CZECH_DIA "$j53"
		TEXT_STRIP_UNPRINTABLE_CHARS "$j53"
	done
}

function CSV_COMMA_TO_SEMICOLON_UBER {
	if [[ $1 == "--help" ]] || ([[  -z $1 ]] && [[ -z $souborCSV ]] ) ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}  <file.csv>
	     \rzmeni carkovou syntaxi csv na semicolon
	     \ra zaroven necha desetinnou carku na pokoji"
	     return
	fi

	[[ ! -z $1 ]] && local souborCSV=$1

	# dodelat input z pipy

	# upravi nadpis --- data --- symbol korun --- uvozovky
	local temp=`cat "$souborCSV" | sed '1 s/,/;/g' | sed '1 s/ /_/g' |  sed '1 s/-//g' | sed '1 s|/|_|g' | sed 's/,\"/;\"/g' | sed 's/ Kč//g' | tr -d '""'`
	echo "$temp" > "$souborCSV"
}

function CSV_SPOLECNY_HEADER_ALL {
	if [[ $1 == "--help" ]] ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}
	     \rvrati soupis vsech hlavicek *.csv v adresari
	     \r  headerSpolecnyPocetSLoupcu - vraci kladny integer
	     \r  headerSpolecnyPoleHotnot - vraci pole 
	     \r  headerSpolecnyHodnotySloupcu - vraci seznam oddeleny newline"
	     return
	fi

	tempHeader=`for i in *.csv ; do
	     head -n 1 "$i" | TEXT_STRIP_CZECH_DIA | TEXT_STRIP_UNPRINTABLE_CHARS
	done | \
	tr "\n" "," | tr ";" "," | tr "," "\n" | sort | uniq`

	headerSpolecnyPocetSloupcu=`echo "$tempHeader" | wc -l `	# vraci cislo
	headerSpolecnyHodnotySloupcu="$tempHeader"					# vraci seznam oddeleny newline
	headerSpolecnyHodnotySloupcuVRadku=`echo "$headerSpolecnyHodnotySloupcu" | tr "\n" " " | tr -d "$" | tr -d '='`


	eval "declare -a headerSpolecnyPoleHodnot=( $headerSpolecnyHodnotySloupcuVRadku )"

	#declare -a a=( "${headerSpolecnyPoleHodnot[@]}" )
}

function CSV_KONVERZE_SOUBORU_DO_UBER-NEW {
	if [[ $1 == "--help" ]] || ([[  -z $1 ]] && [[ -z $souborCSV ]] ) ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}  <file.csv>
	     "
	     return
	fi

	[[ ! -z $1 ]] && local souborCSV=$1

	# priprava souboru
	CSV_COMMA_TO_SEMICOLON_UBER
	TEXT_STRIP_CZECH_DIA $souborCSV
	TEXT_STRIP_UNPRINTABLE_CHARS $souborCSV

	# info
	OS_STRIP_FILENAME $souborCSV  > /dev/null 2>&1

	# vytvor zaklad noveho csv
	echo $headerSpolecnyHodnotySloupcuVRadku | tr " " ";" > $FILENAME_BEG.new

	headerHodnotySloupcu=`head -n 1 $souborCSV | tr ";" " "`

	# akce
	temp111="
    	sed 1d $souborCSV | while IFS=';' read -r $headerHodnotySloupcu 
    	do
	        echo -e \"`echo $headerSpolecnyHodnotySloupcuVRadku | sed 's/ /;\$/g' | sed 's/^/\$/g'`     \"
    	done 
	"
	eval "$temp111" >> $FILENAME_BEG.new
}

function CSV_KONVERZE_CELEHO_ADRESARE {
	if [[ $1 == "--help" ]]  ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}  
	     "
	     return
	fi

	for e in *.csv ; do
		CSV_KONVERZE_SOUBORU_DO_UBER-NEW "$e"
	done
}

function CSV_MERGE_NEWS {
	if [[ $1 == "--help" ]]  ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}  
	     "
	     return
	fi

	# zalozime final soubor
	head -n 1 `ls *.new | head -n 1` > csv.merge


	for i in *.new ; do
		sed 1d "$i" >> csv.merge
	done	
}

function CSV_NAJDI_A_SMAZ_DUPLICITY {
	if [[ $1 == "--help" ]] ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}  <file.csv>
	     "
	     return
	fi

	[[ ! -z $1 ]] && local souborCSV=$1

	OS_STRIP_FILENAME $souborCSV  > /dev/null 2>&1

	cat "$souborCSV" | sort -k `CSV_KTERY_SLOUPEC ID_cesty` | uniq | grep -Ev '^\s*$'    > "$FILENAME_BEG".uniq
}

function CSV_NAJDI_CHYBEJICI {
	if [[ $1 == "--help" ]] || ([[  -z $1 ]] && [[ -z $souborCSV ]] ) ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}  <file.csv> <rok>
	     "
	     return
	fi

	## vars
	[[ ! -z $1 ]] && local souborCSV=$1
	local ROK=2019  	#default
	[[ ! -z $2 ]] && local ROK=$2


	## akce

	# nacti nadpisy ...
	temphead=`head -n 1 $souborCSV | tr ";" " "`

	# ktery sloupec je rok ?
		eval "declare -a headerTempPole=( $temphead )"
	for k in "${!headerTempPole[@]}"; do
   		[[ "${headerTempPole[$k]}" = "Datum-Rok" ]] && break
	done
	local sloupecROK=$((k+1))

	# ktery sloupec je mesic?
	for k in "${!headerTempPole[@]}"; do
   		[[ "${headerTempPole[$k]}" = "Datum-Mesic" ]] && break
	done
	local sloupecMESIC=$((k+1))

	# ktery sloupec je den?
	for k in "${!headerTempPole[@]}"; do
   		[[ "${headerTempPole[$k]}" = "Datum-Den" ]] && break
	done
	local sloupecDEN=$((k+1))


	# vylistujeme final soubor s vybranymi sloupci
	ZAJEM=`cat $souborCSV | cut -d ';' -f"$sloupecROK","$sloupecMESIC","$sloupecDEN"  | tr -d "."  | sort | uniq     `


	for i in {0..11} ; do    #mesice
		aktualniMesic=${mesiceVRoce[$i]}
		#echo "aktualni mesic ..... $aktualniMesic"
		#echo "maximalni den ....... $maximalniDen"
		echo
		for (( j=1 ; j<=${dnyVMesici[${mesiceVRoce[$i]}]} ; j++ )) ; do
			[[ `echo "$ZAJEM" | grep $ROK | grep "${mesiceVRoce[$i]}" | cut -d ';' -f1 | grep ^$j$ ` ]] || echo "chybi $ROK-${mesiceVRoce[$i]}-$j"
		done
	done
}

function CSV_UBER_SOUCET {
	if [[ $1 == "--help" ]] || ([[  -z $3 ]] && [[ -z $souborCSV ]] )  ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}  <value> <mesic> <rok> <soubor.final>"
	     return
	fi

	[[ ! -z $4 ]] && local souborCSV=$4
	local hodnota=$1
	local mesic=$2
	local rok=$3

	# MINA - zrada pokud bude nekde soucet roven cislu roku .... adho provest check, jestli csv neobsahuje cislo roku v souctu "celkem" "cash" "poplatek"

	local zkoumameCsv=`cat "$souborCSV" | cut -d ';' -f "\`CSV_KTERY_SLOUPEC_VE_FINAL Datum-Rok\`","\`CSV_KTERY_SLOUPEC_VE_FINAL Datum-Mesic\`","\`CSV_KTERY_SLOUPEC_VE_FINAL $hodnota\`"         `
	echo "$zkoumameCsv" | grep $rok | grep "$mesic;" | cut -d ';' -f1 | tr "," "." > temp.csv
	scitacka temp.csv
	rm temp.csv
}

function CSV_UBER_ZJISTI_RIDICE {		# vraci pole ridiciVDanyMesic
	if [[ $1 == "--help" ]] || ([[  -z $3 ]] && [[ -z $souborCSV ]] )  ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}  <mesic> <rok> <soubor.final>"
	     return
	fi

	[[ ! -z $3 ]] && local souborCSV=$3
	local mesic=$1
	local rok=$2

	local zkoumameCsv=`cat "$souborCSV" | cut -d ';' -f "\`CSV_KTERY_SLOUPEC_VE_FINAL Datum-Rok\`","\`CSV_KTERY_SLOUPEC_VE_FINAL Datum-Mesic\`","\`CSV_KTERY_SLOUPEC_VE_FINAL Jmeno_ridice\`"         `
	ridiciVDanyMesic=`echo "$zkoumameCsv" | grep $rok | grep "$mesic;" | cut -d ';' -f1 | sort | uniq`
}

function CSV_UBER_SOUCET_PER_USER {
	if [[ $1 == "--help" ]] || ([[  -z $3 ]] && [[ -z $souborCSV ]] )  ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}  <value> <mesic> <rok> <user> <soubor.final>"
	     return
	fi

	[[ ! -z $5 ]] && local souborCSV=$5
	local hodnota=$1
	local mesic=$2
	local rok=$3
	local user=$4

	# MINA - zrada pokud bude nekde soucet roven cislu roku .... adho provest check, jestli csv neobsahuje cislo roku v souctu "celkem" "cash" "poplatek"
	
	local zkoumameCsv=`cat "$souborCSV" | cut -d ';' -f "\`CSV_KTERY_SLOUPEC_VE_FINAL Datum-Rok\`","\`CSV_KTERY_SLOUPEC_VE_FINAL Datum-Mesic\`","\`CSV_KTERY_SLOUPEC_VE_FINAL Jmeno_ridice\`","\`CSV_KTERY_SLOUPEC_VE_FINAL $hodnota\`"  `
	local zkoumameCsv=`echo "$zkoumameCsv" | grep $rok | grep "$mesic;" | grep "$user" `
	
	[[ `echo "$zkoumameCsv" | head -n 1 | grep ^"$user".*` ]] &&  local offset=2 || local offset=1

	echo "$zkoumameCsv" | cut -d ';' -f$offset | tr "," "." > temp.csv
	scitacka temp.csv
	rm temp.csv
}









function CSV_EXPANDUJ_CAS {
	if [[ $1 == "--help" ]]  ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}  
	     "
	     return
	fi
	if [[ $1 == "--help" ]] || ([[  -z $1 ]] && [[ -z $souborCSV ]] ) ; then 
	     echo -e "Usage :   ${FUNCNAME[0]}  <file.csv>
	     "
	     return
	fi

	[[ ! -z $1 ]] && local souborCSV=$1

	OS_STRIP_FILENAME $souborCSV  > /dev/null 2>&1

	noveSloupceSCasem=$(cat csv.uniq | cut -d ";" -f`CSV_KTERY_SLOUPEC Datum_Cas` | awk '{ print $2 ";" $3 ";" $4 }' | sed '1 s/^.*/Datum-Den;Datum-Mesic;Datum-Rok/' | sed 's|;|\\;|g'  )
	eval declare -a noveSloupceSCasemPOLE=( $noveSloupceSCasem )

	# vytvor novy sloupce
	cislo=0
	local temp=`cat $souborCSV | while IFS= read -r line; do
	     echo "$line;${noveSloupceSCasemPOLE[$cislo]}" 
	     ((cislo++))
	done`

	# smaz stary casovy sloupec
	#neni potreba ....


	echo "$temp" > $FILENAME_BEG.final
}

function CSV_ZJISTI_POCET_SLOUPCU_DLE_STREDNIKU {
	if [[ $1 == "--help" ]] || ([[  -z $1 ]] && [[ -z $souborCSV ]] ) ; then 
         echo -e "Usage :   ${FUNCNAME[0]}  <file.csv>
         \rvraci pocetSloupcu - integer"
         return
    fi

	[[ ! -z $1 ]] && local souborCSV=$1

	# global var
	headerPocetSloupcu=$((`head -n 1 $souborCSV | grep -o ";" | wc -l`+1))
	echo $headerPocetSloupcu
}





