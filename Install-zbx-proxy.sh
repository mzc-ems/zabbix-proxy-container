#!/usr/bin/env bash
# Create Date: 2021-02-17 (parkmh@mz.co.kr / ManHee Park)
# Description: The zabbix proxy server auto installer.

set -e

# Define variables.
OPTIND=1
TEMPCNT=1
TYPE_BASE=./zabbix-proxy

# Error message
function err_msg() { echo "$@" ;} >&2

# Print color message.
function color_msg() { 
  local color="$1"
  shift
  local text="$@"

  case ${color} in
    red    ) tput setaf 1 ; tput bold ;;
    green  ) tput setaf 2 ; tput bold ;;
    yellow ) tput setaf 3 ; tput bold ;;
    blue   ) tput setaf 4 ; tput bold ;;
    grey   ) tput setaf 5 ; tput hold ;;
    white  ) tput setaf 7 ;;
  esac

  echo -en "$text"
  tput sgr0
} 

# Show help
function show_help() {
    echo "How to install for zabbix proxy server."
    echo
    echo "Usage:" 
    echo "  $(basename "$0") [-tns]"
    echo
    echo "Options:"
    echo "  -t <lastest|local>   Reference to Type section"
    echo "  -n <name>            Specify a zabbix proxy server name"
    echo "  -s <host|ip>         Specify the zabbix server hostname or ip address"
    echo "  -h                   This help text"
    echo 
    echo "Type:"
    echo "  lastest              Specify a default type to install container"
    echo "  local                Specify a custom build to install container"
    echo "                       Include a dockerfile"
    exit 1
}

# Pre-install Docker Engine.
function install_docker_pack() {
    if [[ -f /etc/system-release ]]; then
        color_msg green "Install the Docker package from the repository. (CentOS)"
        color_msg yellow "Add Docker's official repository >>> "
        sudo yum-config-manager \
            --add-repo \
            https://download.docker.com/linux/centos/docker-ce.repo
        color_msg yellow "Install the Docker Engine >>> "
        sudo yum install docker-ce docker-ce-cli containerd.io
    elif [[ -f /etc/lsb-release ]]; then
        color_msg green "Install the Docker package from the repository. (Ubuntu)"
        sudo apt-get update && sudo apt-get install \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg-agent \
            software-properties-common
        color_msg yellow "Add Docker's official GPG Key >>> "
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        color_msg yellow "Add Docker's official repository >>> "
        sudo add-apt-repository \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) \
            stable"
        color_msg yellow "Install Docker Engine >>> "
        sudo apt-get update && sudo apt-get install docker-ce docker-ce-cli containerd.io
    else
        err_msg $(color_msg red "Error: check your linux distro system.")
        exit 1
    fi

    # Pre-install Docker Compose.
    color_msg green "Install docker-compose."
    if [[ ! -f /usr/local/bin/docker-compose ]]; then        
        sudo curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi
}

# Install the zabbix proxy server.
function install_zbx_proxy() {
    color_msg green "Start installing zabbix proxy server .....\n"
    if [[ "$TYPE" == local ]]; then    
        docker-compose -f ${TYPE_BASE}_${TYPE}/docker-compose.yml up -d --build
    else
        docker-compose -f ${TYPE_BASE}_${TYPE}/docker-compose.yml up -d
    fi
    sudo docker-compose -f ${TYPE_BASE}_${TYPE} ps
    color_msg green "Service up zabbix-proxy_${TYPE} container."
}

# Main
install_docker_pack

# Short options
if [[ -z "$@" ]] ; then
    err_msg "Error: no options."
    err_msg "run ./$(basename "$0") -h" 
    exit 1
fi

# Option parameters
while getopts ":t:n:s:h" opt; do
    if [[ "$TEMPCNT" -eq 1 ]] && [[ "$opt" =~ [ns] ]]; then
        err_msg "Error: $OPTARG is invalid. The first option must be -t." 
        err_msg "run ./$(basename "$0") -h"
        exit 1    
    fi
    
    case ${opt} in
        t)
            TYPE="$OPTARG"
            if [[ "$TYPE" =~ lastest|local ]]; then
                install_zbx_proxy
            else
                err_msg $(color_msg red "Error: -$opt is invaild argument or select lastest or local.")
                exit 1
            fi
            ;;
        n)
            ZBX_PROXY_NAME="$OPTARG"
            if [[ "$ZBX_PROXY_NAME" =~ ^-[sh] ]]; then 
                err_msg "Error: -$opt is no argument"
                show_help
            elif [[ "$ZBX_PROXY_NAME" =~ [A-Za-z].+$ ]]; then
                CNT=`grep -c '^ZBX_HOSTNAME' ${TYPE_BASE}_${TYPE}/.env_prx`
                if [[ "$CNT" -ne 0 ]]; then
                    err_msg $(color_msg yello "Error: check ZBX_HOSTNAME in the .env_prx files.")
                    exit 1
                else
                    echo "ZBX_HOSTNAME=$ZBX_PROXY_NAME" >> ${TYPE_BASE}_${TYPE}/.env_prx
                fi        
            else
                err_msg "Error: -$opt is invaild argument or the first letter cann't digit or special character"
                echo "$OPTARG"
                exit 1
            fi
            ;;
        s)
            ZBX_SERVER="$OPTARG"
            if [[ "$ZBX_SERVER" =~ ^-[th] ]]; then 
                err_msg "Error: -$opt is no argument"
                show_help
            elif [[ "$ZBX_SERVER" =~ [A-Za-z].+$ ]] || [[ "$ZBX_SERVER" =~ [0-9]{1,3}\.[0-9]{1,3}\.[0-9][{1,3}\.[0-9]{1,3}$ ]]; then
                CNT=`grep -c '^ZBX_SERVER_HOST' ${TYPE_BASE}_${TYPE}/.env_prx`               
                if [[ "$CNT" -ne 0 ]]; then
                    err_msg $(color_msg yello "Error: check ZBX_SERVER in the .env_prx files.")
                    exit 1
                else
                    echo "ZBX_SERVER_HOST=${ZBX_SERVER}" >> ${TYPE_BASE}_${TYPE}/.env_prx
                fi
            else
                err_msg $(color_msg red "Error: -$opt is invaild argument or check hostname or ip address.")
                exit 1
            fi
            ;;
        h)
            show_help
            ;;
        \?)
            err_msg "Invalid option: -$OPTARG"
            show_help
            ;;
        :)
            err_msg "Error: option -$OPTARG requires an argument."
            err_msg "Run ./$(basename "$0") -h" 
            exit 1
            ;;
    esac
    TEMPCNT=$[ $TEMPCNT + 1 ]
done

shift $[ OPTIND - 1 ]

if [[ -z "$TYPE" ]] || [[ -z "ZBX_PROXY_NAME" ]] || [[ -z "$ZBX_SERVER" ]]; then
    show_help
fi

color_msg green "Completed installing zabbix proxy server .....\n"
exit 0