#!/usr/bin/env bash

TYPE=${1:-basic}

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

# Install the zabbix proxy server.
function install_zbx_proxy() {
    $TYPE="$1"

    if [[ $TYPE -eq "basic" ]]; then
        docker-compose -f ./zabbix-proxy_latest/docker-compose.yml up -d
    elif [[ $TYPE -eq "local" ]]; then
        docker-compose -f ./zabbix-proxy_local/docker-compose.yml up -d --build 
    else
        echo "Please enter either $(color_msg yello basic) or $(color_msg yello local)."
    fi
}

# Show help
function show_help() {
    err_msg "How to install for zabbix proxy server."
    err_msg
    err_msg "Usage:" 
    err_msg "  $(basename "$0") [TYPE] [options]"
    err_msg "  $(basename "$0") -h|--help"
    err_msg
    err_msg "Options:"
    err_msg "  -n, --name NAME          Specify a zabbix proxy server name"
    err_msg "  -H, --host HOST|IP       Specify the zabbix server hostname or ip address"
    err_msg 
    err_msg "Type:"
    err_msg "  basic                    Specify a default type to install container"
    err_msg "  local                    Specify a custom build to install container"
    err_msg "                           Include a dockerfile"
    exit 1
}

# Error message
function err_msg() { echo "$@" ;} >&2

# Main process
# Short options
color_msg green "Start installing zabbix proxy server .....\n"

while getopts ":n:H:h" opt; do 
    case $opt in
        n)
            ZBX_PROXY_NAME=$OPTARG
            if [[ "$ZBX_PROXY_NAME" =~ ^[0-9._%+0-]+$ ]]; then
                err_msg "The first letter cann't digit or special character"
            fi
            ;;
        H)
            ZBX_SERVER=$OPTARG
            if [[ "$ZBX_SERVER" =~ ^[0-9._%+0-]+$ || "$ZBX_SERVER" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9][{1,3}\.[0-9]{1,3}$ ]]; then
                echo "OK"
            else
                err_msg $(color_msg red "ERR: Check hostname or IP address.")
            fi
            ;;
        h)
            show_help
            ;;
        :)
            case $OPTARG in
                n) err_msg "ERR: arguments invaild -$OPTARG"
                exit 1
                H) err_msg "ERR: arguments invaild -$OPTARG"
                exit 1
            esac
            ;;
        \?)
            err_msg "Invalid option: -$OPTARG"
            show_help
            exit 1
            ;;
    esac
done

color_msg green "Completed installing zabbix proxy server .....\n"

exit 0