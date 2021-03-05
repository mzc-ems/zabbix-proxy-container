#!/usr/bin/env bash
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
    red    ) echo -en "\e[31m" ;;
    green  ) echo -en "\e[32m" ;;
    yellow ) echo -en "\e[33m" ;;
    cyan   ) echo -en "\e[36m" ;;
  esac

  echo -en "$text"
  echo -en "\e[0m"
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
    echo "  -n <name>           Specify a zabbix proxy server name"
    echo "  -s <host|ip>        Specify the zabbix server hostname or ip address"
    echo "  -h                  This help text"
    echo 
    echo "Type:"
    echo "  latest              Specify a default type to install container"
    echo "  local               Specify a custom build to install container"
    echo "                      Include a dockerfile"
    echo
    echo "WARRINGS:"
    echo "  If there are no arguments for options -n and -s," 
    echo "  the default value is set."
    exit 1
}

# Pre-install Docker Engine.
install_docker_pack() {
    if [ $(command -v docker) ]; then
        color_msg red "The Docker package is already installed.\n"        
    elif [ -f /etc/centos-release ]; then
            color_msg green "Install the Docker package from the repository. (CentOS)\n"
            color_msg yellow "Add Docker's official repository >>> "
            sudo yum install -y yum-utils
            sudo yum-config-manager \
                --add-repo \
                https://download.docker.com/linux/centos/docker-ce.repo
            color_msg yellow "Install the Docker Engine >>> "
            sudo yum install -y docker-ce docker-ce-cli containerd.io
    elif [ -f /etc/system-release ]; then
        if [ $(cut -d ' ' -f1 /etc/system-release) == Amazon ]; then
            color_msg green "Install the Docker package from the repository. (Amazon Linux)\n"
            sudo yum -y install docker
        else
            color_msg yellow "Not supoort to Red Hat Enterprise products.\n"
        fi
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
        sudo apt-get update && sudo apt-get -y install docker-ce docker-ce-cli containerd.io
    else
        err_msg "Error: check your linux distro system."
        exit 1
    fi

    # Pre-install Docker Compose.
    color_msg green "Install docker-compose.\n"
    if [ $(command -v docker-compose) ]; then
        color_msg red "The Docker package is already installed.\n"
    else        
        sudo curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi
}

# Add the zabbix-proxy service in systemd
add_zbx_proxy_service() {        
    if [[ $(command -v systemctl) &&  ! -f /etc/systemd/system/dc-zabbix-proxy.service ]]; then
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
        echo
        color_msg white "Your user rights as a root.\n"
        color_msg white "Adding to the systemd service with something like:\n"
        color_msg white "Modify {DOCKER-COMPOSE HOME DIRECTORY} in dc-zabbix-proxy.service file.\n"
        color_msg yellow "PATH: $PWD/zabbix-proxy-$TYPE\n\n"
        color_msg yellow "      cp dc-zabbix-proxy.service /etc/systemd/system/\n"
        color_msg yellow "      systemctl enable dc-zabbix-proxy.service\n"
        echo
    else
        echo
        color_msg white "Your user rights as a root\n"
        color_msg white "Adding to service in rc.local with something like:\n\n"
        color_msg yellow "      echo \"docker-compose -f $PWD/zabbix-proxy-$TYPE/docker-compose.yml up -d\" >> /etc/rc.local\n" 
        echo
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

    if [ "$?" -eq 0 ]; then
        add_zbx_proxy_service
        sudo docker-compose -f $ZBX_HOME-$TYPE/docker-compose.yml ps
        echo 
        color_msg green "SUCCESS: Service up zabbix-proxy-$TYPE container.\n"
    else
        color_msg red "FAILED: Service up zabbix-proxy-$TYPE container.\n"
        exit 1
    fi
}

# Main
# Check root user.
if [ "$UID" -eq 0 ]; then 
    color_msg red "Run to user account.\n"
    exit 1
elif [ ! $(command -v iptables) ]; then
    color_msg yellow "Check iptables package.\n"
    exit 1
fi

# Short options
if [ -z "$@" ] ; then
    err_msg "Error: no options."
    err_msg "run ./$(basename "$0") -h" 
    exit 1
fi

# Option parameters
while getopts ":t:n:s:h:" opt; do
    if [[ "$TEMPCNT" -eq 1 && "$opt" =~ [ns] ]]; then
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
                # docker service status check on init.d or systemd
                pscount=$(ps -fu root | egrep -c 'docker')
                if [ "$pscount" -eq 0 ]; then 
                    if [ $(ps -p 1 -o comm=) == systemd ]; then
                        sudo systemctl enable docker
                        sudo systemctl start docker
                    elif [ $(ps -p 1 -o comm=) == init ]; then
                        sudo /etc/init.d/docker start
                    fi
                fi
            else
                err_msg "Error: -$opt is invaild argument or select <latest> or <local>."
                exit 1
            fi
            ;;

        n)
            ZBX_PROXY_NAME="$OPTARG"
            if [[ "$ZBX_PROXY_NAME" =~ ^-[tsh] ]]; then 
                err_msg "Error: -$opt is no argument"
                show_help
            elif [[ "$ZBX_PROXY_NAME" =~ [A-Za-z].+$ ]]; then
                count=$(grep -c '^ZBX_HOSTNAME' ${ZBX_HOME}-$TYPE/.env_prx)

                if [ "$count" -ne 0 ]; then
                    err_msg "Error: check ZBX_HOSTNAME in ${ZBX_HOME}-$TYPE/.env_prx file."
                    exit 1
                else
                    echo "ZBX_HOSTNAME=$ZBX_PROXY_NAME" >> $ZBX_HOME-$TYPE/.env_prx
                fi        
            else
                err_msg "Error: -$opt is invaild argument or the first letter cann't digit or special character"
                exit 1
            fi
            ;;

        s)
            ZBX_SERVER="$OPTARG"
            if [[ "$ZBX_SERVER" =~ ^-[tnh] ]]; then 
                err_msg "Error: -$opt is no argument"
                show_help
            elif [[ "$ZBX_SERVER" =~ [A-Za-z].+$ || "$ZBX_SERVER" =~ [0-9]{1,3}\.[0-9]{1,3}\.[0-9][{1,3}\.[0-9]{1,3}$ ]]; then
                count=$(grep -c '^ZBX_SERVER_HOST' ${ZBX_HOME}-$TYPE/.env_prx)

                if [ "$count" -ne 0 ]; then
                    err_msg "Error: check ZBX_SERVER in ${ZBX_HOME}-$TYPE/.env_prx file."
                    exit 1
                else
                    echo "ZBX_SERVER_HOST=$ZBX_SERVER" >> $ZBX_HOME-$TYPE/.env_prx
                fi
            else
                err_msg "Error: -$opt is invaild argument or check <hostname> or <ip address>."
                exit 1
            fi
            ;;
        h)
            if [[ "$OPTARG" =~ ^-[tns] ]]; then
                err_msg "Error: illegal option $OPTARG"
                show_help
            elif [ -z "$OPTARG" ]; then
                show_help
            fi
            ;;

        \?)
            err_msg "invalid option: -$OPTARG"
            show_help
            ;;

        :)
            if [ "$OPTARG" == h ]; then
                show_help
            else
                err_msg "Error: option -$OPTARG requires an argument."
                err_msg "Run ./$(basename "$0") -h" 
                exit 1
            fi
            ;;

    esac
    TEMPCNT=$(( $TEMPCNT + 1 ))
done

shift $(( OPTIND - 1 ))

if [[ -z "$TYPE" || -z "ZBX_PROXY_NAME" || -z "$ZBX_SERVER" ]]; then
    show_help   
else
    install_zbx_proxy
fi


color_msg green "Completed installing zabbix proxy server .....\n"
echo 
color_msg white " This host's egress ip address: "
color_msg cyan "$(curl -sL ifconfig.io)\n"
color_msg white " This proxy server name: "
color_msg cyan "$ZBX_PROXY_NAME\n"
color_msg white " Connect to Zabbix server mode: "
color_msg cyan "Active proxy (default mode)\n"
color_msg white " ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
color_msg white " + Zabbix Server (${ZBX_SERVER}:10051) <-- Zabbix Proxy Server +\n"
color_msg white " ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
echo 
color_msg green "Done :)\n"

exit 0