#!/bin/sh
#
# AT commands for Fibocom FM350-GL modem
# 2025-02-01 by mrhaav
#


[ -n "$INCLUDE_ONLY" ] || {
    . /lib/functions.sh
    . ../netifd-proto.sh
    init_proto "$@"
}

update_IPv4 () {
    proto_init_update "$ifname" 1
    proto_set_keep 1
    proto_add_ipv4_address "$v4address" "$v4netmask"
    proto_add_ipv4_route "$v4gateway" "128"
    [ "$defaultroute" = 0 ] || proto_add_ipv4_route "0.0.0.0" 0 "$v4gateway"
    [ "$peerdns" = 0 ] || {
        proto_add_dns_server "$v4dns1"
        proto_add_dns_server "$v4dns2"
    }
    [ -n "$zone" ] && {
        proto_add_data
        json_add_string zone "$zone"
        proto_close_data
    }
    proto_send_update "$interface"
}

update_DHCPv6 () {
    json_init
    json_add_string name "${interface}6"
    json_add_string ifname "@$interface"
    json_add_string proto "dhcpv6"
    proto_add_dynamic_defaults
    json_add_string extendprefix 1
    [ "$peerdns" = 0 -o "$v6dns_ra" = 1 ] || {
        json_add_array dns
        json_add_string "" "$v6dns1"
        json_add_string "" "$v6dns2"
        json_close_array
    }
    [ -n "$zone" ] && json_add_string zone "$zone"
    json_close_object
    [ "$atc_debug" -ge 1 ] && echo JSON: $(json_dump)
    ubus call network add_dynamic "$(json_dump)"
}

release_interface () {
    proto_init_update "$ifname" 0
    proto_send_update "$interface"
}

subnet_calc () {
    local IPaddr=$1
    local A B C D 
    local x y netaddr res subnet gateway

    A=$(echo $IPaddr | awk -F '.' '{print $1}')
    B=$(echo $IPaddr | awk -F '.' '{print $2}')
    C=$(echo $IPaddr | awk -F '.' '{print $3}')
    D=$(echo $IPaddr | awk -F '.' '{print $4}')

    x=1
    y=4
    netaddr=$((y-1))
    res=$((D%y))

    while [ $res -eq 0 ] || [ $res -eq $netaddr ]
    do
        x=$((x+1))
        y=$((y*2))
        netaddr=$((y-1))
        res=$((D%y))
    done

    subnet=$((31-x))
    gateway=$((D/y))
    [ $res -eq 1 ] && gateway=$((gateway*y+2)) || gateway=$((gateway*y+1))
    echo $subnet $A.$B.$C.$gateway
}

IPversion () {

    local addr
    local version=NULL

    addr=$(echo $1 | tr -c -d '.' | wc -c)
    [ $addr -eq 3 ] && version='IPv4'
    [ $addr -eq 15 ] && version='IPv6'

    echo $version
}

IPv6_decTOhex () {
    local ipv6_dec=$1
    local ipv6_hex
    local dec_nb h_part l_part

    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16
    do
       dec_nb=$(echo $ipv6_dec | awk -F '.' '{print $'$i'}')
       h_part=$(echo $(($dec_nb/16)))
       l_part=$(echo $(($dec_nb%16)))
       ipv6_hex=$ipv6_hex$(printf '%x' $h_part)
       ipv6_hex=$ipv6_hex$(printf '%x' $l_part)
       [ $(($i%2)) -eq 0 -a $i -lt 16 ] && ipv6_hex=$ipv6_hex':'
    done

    echo $ipv6_hex
}

nb_rat () {
    local rat_nb=$1
    case $rat_nb in
        0|1|3 )
            rat_nb=GSM ;;
        2|4|5|6 )
            rat_nb=WCDMA ;;
        7 )
            rat_nb=LTE ;;
        11 )
            rat_nb=NR ;;
        13 )
            rat_nb=LTE-ENDC
    esac
    echo $rat_nb
}

CxREG () {
    local reg_string=$1
    local lac_tac g_cell_id rat reject_cause

    lac_tac=$(echo $reg_string | awk -F ',' '{print $2}')
    g_cell_id=$(echo $reg_string | awk -F ',' '{print $3}')
    rat=$(echo $reg_string | awk -F ',' '{print $4}')
    rat=$(nb_rat $rat)
    reject_cause=$(echo $reg_string | awk -F ',' '{print $6}')
    [ "$rat" = 'WCDMA' ] && {
        reg_string='RNCid: '$(printf '%d' 0x${g_cell_id:: -4})' LAC:'$(printf '%d' 0x$lac_tac)' CellId:'$(printf '%d' 0x${g_cell_id: -4})
    }
    [ "${rat::3}" = 'LTE' ] && {
        reg_string='TAC:'$(printf '%d' 0x$lac_tac)' eNodeB:'$(printf '%d' 0x${g_cell_id:: -2})'-'$(printf '%d' 0x${g_cell_id: -2})
    }
    [ "$reject_cause" -gt 0 ] && reg_string=$reg_string' - Reject cause: '$reject_cause

    echo $reg_string
}

full_apn () {
    local apn=$1
    local rest

    rest=$(echo ${apn#*'.mnc'})
    rest=${#rest}
    rest=$((rest+4))
    [ $rest -lt ${#apn} ] && apn=${apn:: -$rest}

    echo $apn
}

proto_atc_init_config() {
    no_device=1
    available=1
    proto_config_add_string "device:device"
    proto_config_add_string "apn"
    proto_config_add_string "pincode"
    proto_config_add_string "pdp"
    proto_config_add_string "auth"
    proto_config_add_string "username"
    proto_config_add_string "password"
    proto_config_add_string "atc_debug"
    proto_config_add_string "delay"
    proto_config_add_string "v6dns_ra"
    proto_config_add_defaults
}

proto_atc_setup () {
    local interface="$1"
    local sms_rx_folder=/var/sms/rx
    local OK_received=0
    local re_connect=0
    local pdp_still_active=0
    local atOut dual_stack manufactor model fw used_apn lines x at_line at_command
    local dns1 dns2 rat new_rat ifname plmn cops_format status sms_index sms_pdu
    local devname devpath device apn pdp pincode auth username password delay atc_debug $PROTO_DEFAULT_OPTIONS
    json_get_vars device ifname apn pdp pincode auth username password delay atc_debug v6dns_ra $PROTO_DEFAULT_OPTIONS

    local custom_at=$(uci get network.${interface}.custom_at 2>/dev/null)

    mkdir -p $sms_rx_folder

    [ -z "$delay" ] && delay=15
    [ ! -f /var/fm350.status ] && {
        echo 'Modem boot delay '$delay's'
        sleep "$delay"
    }

    [ -z $ifname ] && {
        devname=$(basename $device)
        case "$devname" in
            *ttyACM*)
                devpath="$(readlink -f /sys/class/tty/$devname/device)"
                [ -n "$devpath" ] && ifname="$(ls  $devpath/../*/net/)" 2>/dev/null
                ;;
            *ttyUSB*)
                devpath="$(readlink -f /sys/class/tty/$devname/device)"
                [ -n "$devpath" ] && ifname="$(ls $devpath/../../*/net/)"  2>/dev/null
                ;;
        esac
    }
    [ -n "$ifname" ] || {
        echo "No interface could be found yet"
        sleep 3
#        proto_notify_error "$interface" NO_IFACE
#        proto_set_available "$interface" 0
#        proto_block_restart "$interface"
        return 1
    }

    zone="$(fw3 -q network "$interface" 2>/dev/null)"
    echo 0 > /tmp/fm350.status
    echo Initiate modem with interface $ifname

# Set error codes to verbose
    atOut=$(COMMAND='AT+CMEE=2' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    while [ $atOut != 'OK' ]
    do
        echo 'Modem not ready yet: '$atOut
        sleep 1
        atOut=$(COMMAND='AT+CMEE=2' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    done
    
# Check SIMcard and PIN status
    atOut=$(COMMAND='AT+CPIN?' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep CPIN: | awk -F ' ' '{print $2 $3}' | sed -e 's/[\r\n]//g')
    while [ -z "$atOut" ]
    do
        atOut=$(COMMAND='AT+CPIN?' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep CPIN: | awk -F ' ' '{print $2 $3}' | sed -e 's/[\r\n]//g')
    done
    case $atOut in
        READY )
            echo SIMcard ready
            ;;
        SIMPIN )
            if [ -z "$pincode" ]
            then
                echo PINcode required but missing
                proto_notify_error "$interface" PINmissing
                proto_block_restart "$interface"
                return 1
            fi
            atOut=$(COMMAND='AT+CPIN="'$pincode'"' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep 'CME ERROR:')
            if [ -n "$atOut" ]
            then
                echo PINcode error: ${atOut:11}
                proto_notify_error "$interface" PINerror
                proto_block_restart "$interface"
                return 1
            fi
            echo PINcode verified
            ;;
        * )
            echo SIMcard error: $atOut
            proto_notify_error "$interface" PINerror
            proto_block_restart "$interface"
            return 1
            ;;
    esac

# Enable flightmode
    atOut=$(COMMAND='AT+CFUN=4' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    conStatus=offline

# Get modem manufactor and model
    atOut=$(COMMAND='ATI' gcom -d "$device" -s /etc/gcom/getrun_at.gcom)
    manufactor=$(echo "$atOut" | grep Manufacturer | awk -F ':' '{print $2}' | sed -e 's/\r//g')
    manufactor=${manufactor:1}
    model=$(echo "$atOut" | grep Model | awk -F ':' '{print $2}' | sed -e 's/\r//g')
    model=${model:1}
    fw=$(echo "$atOut" | grep Revision | awk -F ':' '{print $2}' | sed -e 's/\r//g')
    fw=${fw:1}
    [ "$atc_debug" -gt 1 ] && {
        echo $manufactor
        echo $model
        echo $fw
    }
    [ "$manufactor" = 'Fibocom Wireless Inc.' -a "$model" = FM350-GL ] || {
        echo 'Modem: '$manufactor' - '$model
        echo 'Wrong script. This is optimized for: Fibocom Wireless Inc. - FM350-GL'
        proto_notify_error "$interface" MODEM
        proto_set_available "$interface" 0
    }
    echo Configure modem

# URC, +CGREG, +CEREG and C5GREG
    atOut=$(COMMAND='AT+CREG=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CGREG=3' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CEREG=3' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+C5GREG=3' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    
# CGEREG, for URCcode +CGEV
    atOut=$(COMMAND='AT+CGEREP=2,1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# Configure PDPcontext, initial profile and profile 1
    atOut=$(COMMAND='AT+EIAAPN="'$apn'"',0,'"'$pdp'","'$pdp'",'$auth',"'$username'","'$password'"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CGDCONT=1,"'$pdp'","'$apn'"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# Timezone reporting
    atOut=$(COMMAND='AT+CTZR=1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# SMS config
    atOut=$(COMMAND='AT+CMGF=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CSCS="GSM"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CNMI=2,1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# Custom AT-commands
    [ $(echo $custom_at | wc -w) -gt 0 ] && {
        echo 'Running custom AT-commands'
        for at_command in $custom_at
        do
            [ $(echo ${at_command::2} | awk '{print toupper($0)}') = 'AT' ] && {
                echo $at_command
                atOut=$(COMMAND=$at_command gcom -d "$device" -s /etc/gcom/getrun_at.gcom)
                lines=$(echo "$atOut" | wc -l)
                x=1
                while [ $x -le $lines ]
                do
                    at_line=$(echo "$atOut" | sed -n $x'p' | sed -e 's/[\r\n]//g')
                    [ $(echo ${#at_line}) -gt 0 -a "$at_line" != "$at_command" ] && echo ' '$at_line
                    x=$((x+1))
                done
            } || {
                echo 'Start custom AT-command with "AT", '$at_command
            }
        done
    }

# Disable flightmode
    echo Activate modem
    COMMAND='AT+CFUN=1' gcom -d "$device" -s /etc/gcom/at.gcom

    while read URCline
    do
        firstASCII=$(printf "%d" \'${URCline::1})
        if [ ${firstASCII} != 13 ] && [ ${firstASCII} != 32 ] && [ ${#URCline} -gt 1 ]
        then
            URCcommand=$(echo $URCline | awk -F ':' '{print $1}')
            URCcommand=$(echo $URCcommand | sed -e 's/[\r\n]//g')
            URCvalue=$(echo $URCline | awk -F ':' '{print $2}')
            URCvalue=$(echo $URCvalue | sed -e 's/"//g' | sed -e 's/[\r\n]//g')
            [ "${URCvalue::1}" = ' ' ] && ${URCvalue:1}
            case $URCcommand in

                +CGREG|+CEREG )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    status=$(echo $URCvalue | awk -F ',' '{print $1}')
                    [ ${#URCvalue} -gt 6 ] && {
                        new_rat=$(echo $URCvalue | awk -F ',' '{print $4}')
                        new_rat=$(nb_rat $new_rat)
                    }
                    case $status in
                        0 )
                            echo ' '$conStatus' -> notRegistered, '$(CxREG $URCvalue)
                            conStatus='notRegistered'
                            ;;
                        1 )
                            if [ "$conStatus" = 'registered' ]
                            then
                                [ "$atc_debug" -ge 1 ] && echo 'Cell change, '$(CxREG $URCvalue)
                                [ "$new_rat" != "$rat" -a -n "$rat" ] && {
                                    echo 'RATchange: '$rat' -> '$new_rat
                                    rat=$new_rat
                                }
                            else
                                echo ' '$conStatus' -> registered - home network, '$(CxREG $URCvalue)
                                conStatus='registered'
                                [ $re_connect -eq 1 ] && {
                                    pdp_still_active=0
                                    COMMAND='AT+CGACT?' gcom -d "$device" -s /etc/gcom/at.gcom
                                    OK_received=10
                                }
                            fi
                            ;;
                        2 )
                            echo ' '$conStatus' -> searching '$(CxREG $URCvalue)
                            conStatus='searching'
                            ;;
                        3 )
                            echo 'Registration denied, '$(CxREG $URCvalue)
                            proto_notify_error "$interface" REG_DENIED
                            proto_block_restart "$interface"
                            return 1
                            ;;
                        4 )
                            echo 'Unknown'
                            ;;
                        5 )
                            if [ "$conStatus" = 'registered' ]
                            then
                                [ "$atc_debug" -ge 1 ] && echo 'Cell change, '$(CxREG $URCvalue)
                                [ "$new_rat" != "$rat" -a -n "$rat" ] && {
                                    echo RATchange: $rat -> $new_rat
                                    rat=$new_rat
                                }
                            else
                                echo ' '$conStatus' -> registered - roaming, '$(CxREG $URCvalue)
                                conStatus='registered'
                                [ $re_connect -eq 1 ] && {
                                    pdp_still_active=0
                                    COMMAND='AT+CGACT?' gcom -d "$device" -s /etc/gcom/at.gcom
                                    OK_received=10
                                }
                            fi
                            ;;
                        esac
                    ;;
                
                +COPS )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    cops_format=$(echo $URCvalue | awk -F ',' '{print $2}')
                    [ $cops_format -eq 0 ] && {
                        operator=$(echo $URCvalue | awk -F ',' '{print $3}' | sed -e 's/"//g')
                    }
                    [ $cops_format -eq 2 ] && {
                        plmn=$(echo $URCvalue | awk -F ',' '{print $3}' | sed -e 's/"//g')
                        rat=$(echo $URCvalue | awk -F ',' '{print $4}')
                        rat=$(nb_rat $rat)
                        echo 'Registered to '$operator' PLMN:'$plmn' on '$rat
                        echo Activate session
                        OK_received=1
                    }
                    ;;
                
                +CGEV )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    case $URCvalue in
                        'EPS PDN DEACT'*|'NW PDN DEACT'* )
                            echo Session disconnected
                            pdp_still_active=0
                            COMMAND='AT+CGACT?' gcom -d "$device" -s /etc/gcom/at.gcom
                            OK_received=10
                            ;;
                        'ME PDN DEACT'* )
                            OK_received=9
                            ;;
                        'ME PDN ACT'* )
                            OK_received=2
                            ;;
                    esac
                    ;;
        
                +CGPADDR )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    v4address=""
                    v6address=""
                    URCvalue=$(echo $URCvalue | sed -e 's/"//g')
                    IPaddress1=$(echo $URCvalue | awk -F ',' '{print $2}')
                    IPaddress2=$(echo $URCvalue | awk -F ',' '{print $3}')
                    [ $(IPversion $IPaddress1) = 'IPv4' ] && {
                        v4address=$IPaddress1
                        v4netmask=$(subnet_calc $v4address)
                        v4gateway=$(echo $v4netmask | awk -F ' ' '{print $2}')
                        v4netmask=$(echo $v4netmask | awk -F ' ' '{print $1}')
                        dual_stack=0
                    }
                    [ $(IPversion $IPaddress1) = 'IPv6' ] && {
                        v6address=$(IPv6_decTOhex $IPaddress1)
                        dual_stack=0
                    }
                    [ $(IPversion $IPaddress2) = 'IPv6' ] && {
                        v6address=$(IPv6_decTOhex $IPaddress2)
                        dual_stack=1
                    }
                    OK_received=3
                    [ $re_connect -eq 0 ] && re_connect=1
                    ;;

                +EONSNWNAME )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    [ $re_connect -eq 0 ] && {
                        COMMAND='AT+COPS=3,0;+COPS?;+COPS=3,2;+COPS?' gcom -d "$device" -s /etc/gcom/at.gcom
                        re_connect=1
                    }
                    ;;

                +CTZV )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    [ $re_connect -eq 0 ] && {
                        COMMAND='AT+COPS=3,0;+COPS?;+COPS=3,2;+COPS?' gcom -d "$device" -s /etc/gcom/at.gcom
                        re_connect=1
                    } || {
                        pdp_still_active=0
                        COMMAND='AT+CGACT?' gcom -d "$device" -s /etc/gcom/at.gcom
                        OK_received=10
                    }
                    ;;

                +CGACT )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    pdp_still_active=$(echo $URCvalue | awk -F ',' '{print $2}')
                    ;;

                '+CME ERROR' )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    [ "$URCvalue" = '5847' ] && {
                        COMMAND='AT+CGACT=1,1' gcom -d "$device" -s /etc/gcom/at.gcom
                    }
                    [ "$URCvalue" = 'Requested service option not subscribed (#33)' ] && {
                        echo 'Activate session failed, check your APN settings'
                        proto_notify_error "$interface" SESSION_FAILED
                        proto_block_restart "$interface"
                        return 1
                    }
                    [ "$URCvalue" = '38' ] && {
                        echo 'Unsuccessful delivery of SMS'
                    }
                    ;;

                +CGCONTRDP )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    [ -z "$used_apn" ] && {
                        used_apn=$(echo $URCvalue | awk -F ',' '{print $3}')
                        used_apn=$(full_apn $used_apn)
                        [ "$apn" != $used_apn ] && echo 'Using network default APN: '$used_apn
                    }
                    dns1=$(echo $URCvalue | awk -F ',' '{print $6}')
                    dns2=$(echo $URCvalue | awk -F ',' '{print $7}')
                    [ -z "$dns1" -a -z "$dns2" -a "$v6dns_ra" != 1 ] && {
                        echo 'No DNS servers provided. Try to activate IPv6 DNS servers via Router Advertisment in Advanced Setting.'
                    }
                    [ $(IPversion $dns1) = 'IPv4' ] && {
                        v4dns1=$dns1
                        v4dns2=$dns2
                    }
                    [ $(IPversion $dns1) = 'IPv6' ] && {
                        v6dns1=$(IPv6_decTOhex $dns1)
                        v6dns2=$(IPv6_decTOhex $dns2)
                    }
                    [ $dual_stack != 1 -o "$v6dns_ra" = 1 ] && {
                        proto_init_update "$ifname" 1
                        proto_set_keep 1
                        proto_add_data
                        json_add_string "modem" "${model}"
                        proto_close_data
                        proto_send_update "$interface"
                        [ -n "$v4address" ] && update_IPv4
                        [ -n "$v6address" ] && update_DHCPv6
                    } || {
                        dual_stack=2
                    }
                    OK_received=4
                    ;;

                +CMTI )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    sms_index=$(echo $URCvalue | awk -F ',' '{print $2}')
                    COMMAND='AT+CMGR='$sms_index gcom -d "$device" -s /etc/gcom/at.gcom
                    ;;

                +CMGR )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    OK_received=11
                    ;;

                +CMGS )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    echo 'SMS successfully sent'
                    ;;

                OK )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    [ $OK_received -eq 12 ] && {
                        [ $sms_index -gt 1 ] && {
                            sms_index=$((sms_index-1))
                            COMMAND='AT+CMGR='$sms_index gcom -d "$device" -s /etc/gcom/at.gcom
                        } || {
                            OK_received=0
                        }
                    }
                    [ $OK_received -eq 11 ] && {
                        COMMAND='AT+CMGD='$sms_index gcom -d "$device" -s /etc/gcom/at.gcom
                        OK_received=12
                    }
                    [ $OK_received -eq 10 -a $pdp_still_active -eq 0 ] && {
                        echo 'Session diconnected by the network'
                        release_interface
                        COMMAND='AT+CGACT=1,1' gcom -d "$device" -s /etc/gcom/at.gcom
                        echo 'Activate session'
                    }
                    [ $OK_received -eq 9 -a $pdp_still_active -eq 0 ] && {
                        echo 'Activate session'
                        COMMAND='AT+CGACT=1,1' gcom -d "$device" -s /etc/gcom/at.gcom
                    }
                    [ $OK_received -eq 3 ] && {
                        COMMAND='AT+CGCONTRDP=1' gcom -d "$device" -s /etc/gcom/at.gcom
                    }
                    [ $OK_received -eq 2 ] && {
                        COMMAND='AT+CGPADDR=1' gcom -d "$device" -s /etc/gcom/at.gcom
                    }
                    [ $OK_received -eq 1 ] && {
                        COMMAND='AT+CGACT=1,1' gcom -d "$device" -s /etc/gcom/at.gcom
                    }
                    ;;

                * )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    [ $OK_received -eq 11 ] && {
                        sms_pdu=$URCline
                        echo 'SMS received'
                        [ "$atc_debug" -gt 1 ] && echo $sms_pdu >> /var/sms/pdus 2> /dev/null
                        /usr/bin/atc_rx_pdu_sms $sms_pdu 2> /dev/null
                    }
                    ;;
            esac
        fi
    done < ${device}
}


proto_atc_teardown() {
    local interface="$1"
    local device=$(uci get network.${interface}.device)
    local atOut
    echo $interface is disconnected
    atOut=$(COMMAND='AT+CGACT=0,1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    proto_init_update "*" 0
    proto_send_update "$interface"
}

[ -n "$INCLUDE_ONLY" ] || {
    add_protocol atc
}
