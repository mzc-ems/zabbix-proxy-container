#!/usr/bin/env bash
set -e
# Create Date: 2021-02-17 (parkmh@mz.co.kr / ManHee Park)
# Description: The zabbix proxy server auto installer.

# Define variables.
OPTIND=1
TEMPCNT=1
ZBX_HOME='./zabbix-proxy'

# Error message
err_msg() { echo "$@"; } >&2

# Print color message.
color_msg() { 
  local color="$1"
  shift
  local text="$@"

  case "$color" in
    red    ) echo -e "\e[31m" ;;
    green  ) echo -e "\e[32m" ;;
    yellow ) echo -e "\e[33m" ;;
    blue   ) echo -e "\e[34m" ;;
  esac

  echo -e "$text"
  echo -e "\e[0m"
} 

# Show help
show_help() {
    echo "How to install for zabbix proxy server."
    echo
    echo "Usage:" 
    echo "  $(basename "$0") [-tns]"
    echo
    echo "Options:"
    echo "  -t <latest|local>   Reference to Type section"
    echo "  -n <name>            Specify a zabbix proxy server name"
    echo "  -s <host|ip>         Specify the zabbix server hostname or ip address"
    echo "  -h                   This help text"
    echo 
    echo "Type:"
    echo "  latest              Specify a default type to install container"
    echo "  local                Specify a custom build to install container"
    echo "                       Include a dockerfile"
    exit 1
}

# Pre-install Docker Engine.
install_docker_pack() {
    if [[ $(command -v docker) ]]; then
        color_msg red "The Docker package is already installed.\n"
    elif [ -f /etc/system-release ]; then
        if [[ $(cut -d ' ' -f1 /etc/system-release) == Amazon ]]; then
            color_msg green "Install the Docker package from the repository. (Amazon Linux)\n"
            sudo yum -y -q install docker
        else
            color_msg green "Install the Docker package from the repository. (Fedora)\n"
            color_msg yellow "Add Docker's official repository >>> "
            sudo dnf install dnf-plugins-core
            sudo dnf config-manager \
                --add-repo \
                https://download.docker.com/linux/fedora/docker-ce.repo
            color_msg yellow "Install the Docker Engine >>> "
            sudo dnf install docker-ce docker-ce-cli containerd.io
        fi
    elif [ -f /etc/centos-release ]; then
            color_msg green "Install the Docker package from the repository. (CentOS)\n"
            color_msg yellow "Add Docker's official repository >>> "
            sudo yum install -y -q yum-utils
            sudo yum-config-manager \
                --add-repo \
                https://download.docker.com/linux/centos/docker-ce.repo
            color_msg yellow "Install the Docker Engine >>> "
            sudo yum install -y docker-ce docker-ce-cli containerd.io
    elif [ -f /etc/lsb-release ]; then
        color_msg green "Install the Docker package from the repository. (Ubuntu)\n"
        sudo apt-get update && sudo apt-get -y -qq install \
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
        sudo apt-get update && sudo apt-get -y -qq install docker-ce docker-ce-cli containerd.io
    else
        err_msg "Error: check your linux distro system."
        exit 1
    fi

    # Pre-install Docker Compose.
    color_msg green "Install docker-compose.\n"
    if [[ $(command -v docker-compose) ]]; then
        color_msg red "The Docker package is already installed.\n"
    else        
        sudo curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi
}

# Install the zabbix proxy server.
install_zbx_proxy() {
    color_msg green "Start installing zabbix proxy server .....\n"
    if [ "$TYPE" == 'local' ]; then    
        sudo docker-compose -f $ZBX_HOME-$TYPE/docker-compose.yml up -d --build
    else
        sudo docker-compose -f $ZBX_HOME-$TYPE/docker-compose.yml up -d
    fi
    sudo docker-compose -f $ZBX_HOME-$TYPE/docker-compose.yml ps
    color_msg green "\nService up zabbix-proxy-$TYPE container.\n"
}

# Add the zabbix-proxy service in systemd
add_zbx_proxy_service() {        
    if [[ $(command -v systemctl) ]] && [ ! -f /etc/systemd/system/dc-zabbix-proxy.service ]; then
        color_msg green "Creating dc-zabbix-proxy service for the systemd >>> "
        cat > dc-zabbix-proxy.service <<-'EOF'
# /etc/systemd/system/dc-zabbix-proxy.service

[Unit]
Description=Docker Compose Zabbix Proxy Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory={DOCKER-COMPOSE HOME DIRECTORY}
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

        color_msg yellow "Your user rights as a root."
        color_msg yellow "Adding to the systemd service with something like:\n"
        color_msg yellow "Modify {DOCKER-COMPOSE HOME DIRECTORY} in dc-zabbix-proxy.service file"
        color_msg yellow "The path is $PWD/zabbix-proxy-$TYPE\n"
        color_msg yellow "      cp dc-zabbix-proxy.service /etc/systemd/system/"
        color_msg yellow "      systemctl enable dc-zabbix-proxy.service"
        color_msg green "Done.\n"
    else
        color_msg yellow "Your user rights as a root"
        color_msg yellow "Adding to service in rc.local with something like:"
        color_msg yellow "      echo \"docker-compose -f $PWD/zabbix-proxy-$TYPE/docker-compose.yml up -d\" >> /etc/rc.local" 
    fi
} 

# Main
# Short options
if [[ -z "$@" ]] ; then
    err_msg "Error: no options."
    err_msg "run ./$(basename "$0") -h" 
    exit 1
fi

# Option parameters
while getopts ":t:n:s:h" opt; do
    if [ "$TEMPCNT" -eq 1 ] && [[ "$opt" =~ [ns] ]]; then
        err_msg "Error: $OPTARG is invalid. The first option must be -t." 
        err_msg "run ./$(basename "$0") -h"
        exit 1    
    fi

    case "$opt" in
        # It is the central part of the processing.
        t)
            TYPE="$OPTARG"
            if [[ "$TYPE" =~ latest|local ]]; then
                install_docker_pack
                install_zbx_proxy
                add_zbx_proxy_service
            else
                err_msg "Error: -$opt is invaild argument or select latest or local."
                exit 1
            fi
            ;;

        n)
            ZBX_PROXY_NAME="$OPTARG"
            if [[ "$ZBX_PROXY_NAME" =~ ^-[sh] ]]; then 
                err_msg "Error: -$opt is no argument"
                show_help
            elif [[ "$ZBX_PROXY_NAME" =~ [A-Za-z].+$ ]]; then
                CNT=$(grep -c '^ZBX_HOSTNAME' $ZBX_HOME-$TYPE/.env_prx)

                if [ "$CNT" -ne 0 ]; then
                    err_msg "Error: check ZBX_HOSTNAME in the .env_prx files."
                    exit 1
                else
                    echo "ZBX_HOSTNAME=$ZBX_PROXY_NAME" >> $ZBX_HOME-$TYPE/.env_prx
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
                CNT=$(grep -c '^ZBX_SERVER_HOST' $ZBX_HOME-$TYPE/.env_prx)

                if [ "$CNT" -ne 0 ]; then
                    err_msg "Error: check ZBX_SERVER in the .env_prx files."
                    exit 1
                else
                    echo "ZBX_SERVER_HOST=$ZBX_SERVER" >> $ZBX_HOME-$TYPE/.env_prx
                fi
            else
                err_msg "Error: -$opt is invaild argument or check hostname or ip address."
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
    TEMPCNT=$(( $TEMPCNT + 1 ))
done

shift $(( OPTIND - 1 ))

if [ -z "$TYPE" ] || [ -z "ZBX_PROXY_NAME" ] || [ -z "$ZBX_SERVER" ]; then
    show_help   
fi

color_msg green "Completed installing zabbix proxy server .....\n"
color_msg green "Done."
exit 0