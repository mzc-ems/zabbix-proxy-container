#!/usr/bin/env bash

OPTND=1

# Error message
function err_msg() { echo "$@" ;} >&2

# Print color message.
function color_msg() { 
  local color=${1}
  shift
  local text="${@}"

  case ${color} in
    red    ) tput setaf 1 ; tput bold ;;
    green  ) tput setaf 2 ; tput bold ;;
    yellow ) tput setaf 3 ; tput bold ;;
    blue   ) tput setaf 4 ; tput bold ;;
    grey   ) tput setaf 5 ;;
  esac

  echo -en "${text}"
  tput sgr0
} 

# Show help
function show_help() {
    err_msg "How to install for zabbix proxy server."
    err_msg
    err_msg "Usage:" 
    err_msg "  $(basename "$0") [options] [TYPE <basic|build>]"
    err_msg
    err_msg "Options:"
    err_msg "  -n <name>          Specify a zabbix proxy server name"
    err_msg "  -s <host|ip>       Specify the zabbix server hostname or ip address"
    err_msg "  -t <basic|build>   Reference to Type section"
    err_msg "  -h                 This help text"
    err_msg 
    err_msg "Type:"
    err_msg "  basic              Specify a default type to install container"
    err_msg "  build              Specify a custom build to install container"
    err_msg "                     Include a dockerfile"
    exit 1
}

# Install the zabbix proxy server.
function install_zbx_proxy() {
    if [[ "$TYPE" == basic ]]; then
        echo "docker-compose -f ./zabbix-proxy_latest/docker-compose.yml up -d"
    elif [[ "$TYPE" == build ]]; then
        echo "docker-compose -f ./zabbix-proxy_local/docker-compose.yml up -d --build"
    else
        echo "Please enter either $(color_msg yello basic) or $(color_msg yello build)."
    fi
}

# Main
# Short options
while getopts ":n:s:t:h" opt; do 
    case $opt in
        n)
            ZBX_PROXY_NAME="$OPTARG"
            if [[ $ZBX_PROXY_NAME =~ ^[A-Za-z].+$ ]]; then
                echo "-n arguments OK"         
            else
                err_msg "error: the first letter cann't digit or special character"
                echo "$OPTARG"
                exit 1
            fi
            ;;
        s)
            ZBX_SERVER="$OPTARG"
            if [[ $ZBX_SERVER =~ ^-n ]] && [[ $ZBX_SERVER =~ ^[A-Za-z].+$ ]] || [[ $ZBX_SERVER =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9][{1,3}\.[0-9]{1,3}$ ]]; then
                echo "-s arguments OK"
            else
                err_msg $(color_msg red "error: check hostname or ip address.")
                echo "$OPTARG"
                exit 1
            fi
            ;;
        t)
            if [[ -z $OPTARG ]] || [[ ! -n $OPTARG ]]; then
                TYPE=basic
                echo " TYPE is default"
            else
                TYPE="$OPTARG"
            fi 
            if [[ $TYPE =~ basic|build ]]; then
                color_msg green "Start installing zabbix proxy server .....\n"
                install_zbx_proxy
                echo "-t arguments OK"
            else
                err_msg $(color_msg red "error: select basic or build.")
                echo "$OPTARG"
                exit 1
            fi
            ;;
        h)  show_help ;;
        \?)
            err_msg "Invalid option: -$OPTARG"
            show_help
            exit 1
            ;;
        :)
            err_msg "Option -$OPTARG requires an argument."
            err_msg "Run ./$(basename "$0") -h" 

            exit 1
            ;;
    esac
done

shift $(( OPTND - 1 ))
echo "-n ARG is $ZBX_PROXY_NAME"
echo "-s ARG is $ZBX_SERVER"
echo "-t ARG is $TYPE"
color_msg green "Completed installing zabbix proxy server .....\n"

exit 0