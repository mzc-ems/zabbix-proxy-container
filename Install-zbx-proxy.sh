#!/usr/bin/env bash
# Create Date: 2021-02-17 (parkmh@mz.co.kr / ManHee Park)
# Description: The zabbix proxy server auto installer.

OPTND=1
TYPE_BASE='./zabbix-proxy'

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
    err_msg "  $(basename "$0") [-tns]"
    err_msg
    err_msg "Options:"
    err_msg "  -t <lastest|local>   Reference to Type section"
    err_msg "  -n <name>            Specify a zabbix proxy server name"
    err_msg "  -s <host|ip>         Specify the zabbix server hostname or ip address"
    err_msg "  -h                   This help text"
    err_msg 
    err_msg "Type:"
    err_msg "  lastest              Specify a default type to install container"
    err_msg "  local                Specify a custom build to install container"
    err_msg "                       Include a dockerfile"
    exit 1
}

# Install the zabbix proxy server.
function install_zbx_proxy() {
    if [[ "$TYPE" == lastest ]]; then
        echo "docker-compose -f ./zabbix-proxy_latest/docker-compose.yml up -d"
    elif [[ "$TYPE" == 'local' ]]; then
        echo "docker-compose -f ./zabbix-proxy_local/docker-compose.yml up -d --build"
    else
        echo "Please enter either $(color_msg yello basic) or $(color_msg yello build)."
    fi
}

# Pre-install Docker Engine.
function install_docker_pack() {
    if [[ -n /etc/system-release ]]; then
        color_msg green "Install the Docker package from the repository. (CentOS)"
        color_msg yellow "Add Docker's official repository >>> "
        sudo yum-config-manager \
            --add-repo \
            https://download.docker.com/linux/centos/docker-ce.repo
        color_msg yellow "Install the Docker Engine >>> "
        sudo yum install docker-ce docker-ce-cli containerd.io
    elif [[ -n /etc/lsb-release ]]; then
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
        err_msg $(color_msg red "error: check your linux distro system.")
        exit 1
    fi

# Pre-install Docker Compose.
color_msg green "Install docker-compose."
sudo curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
}

# Short options
while getopts ":t:n:s:h" opt; do 
    case $opt in
        t)
            if [[ -z "$OPTARG" ]] || [[ ! -n "$OPTARG" ]]; then
                TYPE=lastest
                echo " TYPE is default"
            else
                TYPE="$OPTARG"
            fi 
            if [[ "$TYPE" =~ lastest|local ]]; then
                install_docker_pack
                color_msg green "Start installing zabbix proxy server .....\n"
                install_zbx_proxy
                echo "-t arguments OK"
            else
                err_msg $(color_msg red "error: select lastest or local.")
                echo "$OPTARG"
                exit 1
            fi
            ;;
        n)
            ZBX_PROXY_NAME="$OPTARG"
            if [[ "$ZBX_PROXY_NAME" =~ ^-t ]] || [[ "$ZBX_PROXY_NAME" =~ ^[A-Za-z].+$ ]]; then
                echo "-n arguments OK"
                 CNT=`grep -c 'ZBX_HOSTNAME' ${TYPE_BASE}_${TYPE}/.env_prx`
                
                if [[ "$CNT" -ne 0 ]]; then
                    err_msg $(color_msg yello "error: check ZBX_HOSTNAME in the .env_prx files.")
                    exit 1
                else
                    echo "ZBX_HOSTNAME=$ZBX_PROXY_NAME" >> ${TYPE_BASE}_${TYPE}/.env_prx
                fi        
            else
                err_msg "error: the first letter cann't digit or special character"
                echo "$OPTARG"
                exit 1
            fi
            ;;
        s)
            ZBX_SERVER="$OPTARG"
            if [[ "$ZBX_SERVER" =~ ^-n ]] || [[ "$ZBX_SERVER" =~ ^[A-Za-z].+$ ]] || [[ "$ZBX_SERVER" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9][{1,3}\.[0-9]{1,3}$ ]]; then
                echo "-s arguments OK"
                CNT=`grep -c 'ZBX_SERVER_HOST' ${TYPE_BASE}_${TYPE}/.env_prx`
                
                if [[ "$CNT" -ne 0 ]]; then
                    err_msg $(color_msg yello "error: check ZBX_SERVER in the .env_prx files.")
                    exit 1
                else
                    echo "ZBX_SERVER_HOST=${ZBX_SERVER}" >> ${TYPE_BASE}_${TYPE}/.env_prx
                fi
            else
                err_msg $(color_msg red "error: check hostname or ip address.")
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