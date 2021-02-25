# zabbix-proxy-container
### 1. 배경
* Zabbix Proxy 운영 및 관리를 단순화하기 위해 Container르 구성하여 서비스를 구성합니다.
* 이미지는 aㅣpine 기반이며 DB는 sqlite3로 구성합니다.

### 2. 구성 요소
* Docker engine
* Docker-compose
* Zabbix docker-compose YAML 파일.

### 3. 전제 조건
* 소스 코드를 받기 위해 git이 설치되어 있어야 합니다.
* 해당 소스 내에서 docker image 및 dockerfile 다운로드르 위해 443 포트가 개방되어야 합니다.

### 4. 지원 Platform
* Amazon Linux & Amazon Linux 2
* Ubuntu 12.04 later
* CentOs 7 & 8

### 5. 사용법
```
# User 계정을 Linux Server 터미널에 로그인합니다.
]$ git clone https://github.com/mzc-ems/zabbix-proxy-container.git 
]$ cd zabbix-proxy-container
]$ ./zabbix-proxy-container -h
How to install for zabbix proxy server.

Usage:
  Install-zbx-proxy.sh [-tns]

Options:
  -t <latest|local>   Reference to Type section
  -n <name>           Specify a zabbix proxy server name
  -s <host|ip>        Specify the zabbix server hostname or ip address
  -h                  This help text

Type:
  latest              Specify a default type to install container
  local               Specify a custom build to install container
                      Include a dockerfile

WARRINGS:
  If there are no arguments for options -n and -s,
  the default value is set.
```
* 예시
```
]$ ./Install-zbx-proxy.sh -t latest -n test-amazonlinux2 -s 52.78.54.207
```
* 출력물
```
Creating dc-zabbix-proxy service for the systemd >>>
Your user rights as a root.
Adding to the systemd service with something like:
Modify {DOCKER-COMPOSE HOME DIRECTORY} in dc-zabbix-proxy.service file
The path is /home/ec2-user/zabbix-proxy-container/zabbix-proxy-latest

      cp dc-zabbix-proxy.service /etc/systemd/system/
      systemctl enable dc-zabbix-proxy.service

                   Name                                 Command               State            Ports
--------------------------------------------------------------------------------------------------------------
zabbix-proxy-latest_zabbix-proxy-sqlite3_1   /sbin/tini -- /usr/bin/doc ...   Up      0.0.0.0:10051->10051/tcp

SUCCESS: Service up zabbix-proxy-latest container.
Completed installing zabbix proxy server .....

 This host's egress ip address: 52.79.177.107
 This proxy server name: test-amazonlinux2
 Connect to Zabbix server mode: Active proxy (default mode)
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 + Zabbix Server (52.78.54.207:10051) <-- Zabbix Proxy Server +
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Done :)
```

### 5. 맺음말
* 설치 이후에 Zabbix Proxy Server의 Parameter 변경은 Type을 변경한 디렉토리의 .env_prx를 확인하세요.
* 자세한 정보는 아래 링크를 통해 확인하세요.
[Official Zabbix Dockerfiles](https://github.com/zabbix/zabbix-docker)
[Official Docker Engine](https://docs.docker.com/engine/install)
