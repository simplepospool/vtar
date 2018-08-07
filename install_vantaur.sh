#!/bin/bash
 
TMP_FOLDER=$(mktemp -d)
CONFIG_FILE='Vantaur.conf'
CONFIGFOLDER='/root/.Vantaur'
COIN_DAEMON='vantaurd'
COIN_CLI='vantaurd'
COIN_PATH='/usr/local/bin/'
COIN_TGZ='https://github.com/simplepospool/vtar/releases/download/1.0/vantaurd.zip'
COIN_NAME='Vantaur'
COIN_PORT=22813
RPC_PORT=22812
 
NODEIP=$(curl -s4 icanhazip.com)
 
 
RED=''
YELLOW=''
GREEN=''
NC=''
 
function download_node() {
  echo -e "Downloading and installing latest ${GREEN}$COIN_NAME${NC} coin daemon."
  cd $TMP_FOLDER >/dev/null 2>&1
  wget -q $COIN_TGZ -O $COIN_DAEMON.zip --show-progress
  compile_error
  unzip -j $COIN_DAEMON.zip >/dev/null 2>&1
  compile_error
  rm $COIN_DAEMON.zip
  chmod +x *
  cp $COIN_DAEMON $COIN_PATH
  cp $COIN_CLI $COIN_PATH
  cd ~ >/dev/null 2>&1
  rm -rf $TMP_FOLDER >/dev/null 2>&1
  clear
}
 
 
function configure_systemd() {
  cat << EOF > /etc/systemd/system/$COIN_NAME.service
[Unit]
Description=$COIN_NAME service
After=network.target
 
[Service]
User=root
Group=root
 
Type=forking
#PIDFile=$CONFIGFOLDER/$COIN_NAME.pid
 
ExecStart=$COIN_PATH$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
ExecStop=-$COIN_PATH$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop
 
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
 
[Install]
WantedBy=multi-user.target
EOF
 
  systemctl daemon-reload
  sleep 3
  systemctl start $COIN_NAME.service
  systemctl enable $COIN_NAME.service >/dev/null 2>&1
 
  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
    echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $COIN_NAME.service"
    echo -e "systemctl status $COIN_NAME.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}
 
 
function create_config() {
  mkdir $CONFIGFOLDER >/dev/null 2>&1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcport=$RPC_PORT
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
port=$COIN_PORT
EOF
}
 
function create_key() {
  echo -e "Enter your ${RED}$COIN_NAME Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
  read -t 10 -e COINKEY
  if [[ -z "$COINKEY" ]]; then
  $COIN_PATH$COIN_DAEMON -daemon
  sleep 30
  if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
   echo -e "${RED}$COIN_NAME server couldn not start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
  if [ "$?" -gt "0" ];
    then
    echo -e "${RED}Wallet not fully loaded. Let us wait and try again to generate the Private Key${NC}"
    sleep 30
    COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
  fi
  $COIN_PATH$COIN_CLI stop
fi
clear
}
 
function update_config() {
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE
#bind=$NODEIP
masternode=1
masternodeaddr=$NODEIP:$COIN_PORT
masternodeprivkey=$COINKEY
maxconnections=64
externalip=$NODEIP:$COIN_PORT
addnode=159.89.95.51:22813
addnode=79.198.191.160:43491
addnode=149.167.15.12:36330
addnode=14.12.32.0:34510
addnode=5.76.41.51:63368
addnode=58.17.70.114:62204
addnode=87.228.35.65:54448
addnode=83.135.157.147:50230
addnode=71.231.44.58:22813
addnode=82.76.136.135:62379
addnode=76.236.82.186:51988
addnode=84.52.203.227:62704
addnode=89.169.35.44
addnode=185.117.44.10:55277
addnode=223.84.182.134:50249
addnode=116.108.102.240:49405
addnode=94.156.189.212:41954
addnode=86.4.68.248:62228
addnode=27.17.251.77:42616
addnode=93.138.105.110:59960
addnode=178.85.130.37:34747
addnode=109.96.169.231:49704
addnode=93.184.160.141:47418
addnode=91.151.111.250:38406
addnode=83.102.218.27
addnode=133.203.108.63:60479
addnode=191.177.186.201:22495
addnode=124.227.240.15:3403
addnode=109.70.187.202:2795
addnode=117.30.218.197:23893
addnode=141.136.186.218:51707
addnode=203.114.235.222:21012
addnode=83.99.248.71:58274
addnode=86.88.39.133:52300
addnode=51.15.164.56:59328
addnode=46.61.152.191:62369
addnode=37.59.48.93:36936
addnode=78.27.136.165:22813

EOF
}
 
 
function enable_firewall() {
  echo -e "Installing and setting up firewall to allow ingress on port ${GREEN}$COIN_PORT${NC}"
  ufw allow $COIN_PORT/tcp comment "$COIN_NAME MN port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}
 
 
function get_ip() {
  declare -a NODE_IPS
  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))
  done
 
  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
      echo -e "${GREEN}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
      INDEX=0
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
  fi
}
 
 
function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $COIN_NAME. Please investigate.${NC}"
  exit 1
fi
}
 
 
function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi
 
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi
 
if [ -n "$(pidof $COIN_DAEMON)" ] || [ -e "$COIN_DAEMON" ] ; then
  echo -e "${RED}$COIN_NAME is already installed.${NC}"
  exit 1
fi
}
 
function prepare_system() {
echo -e "Prepare the system to install ${GREEN}$COIN_NAME${NC} master node."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
libminiupnpc-dev libgmp3-dev libzmq3-dev ufw pkg-config libevent-dev mc libdb5.3++ unzip >/dev/null 2>&1
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libzmq3-dev libboost-test-dev libboost-thread-dev sudo automake git curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw pkg-config mc libevent-dev libdb5.3++ unzip"
 exit 1
fi
clear
}
 
function important_information() {
 echo -e "================================================================================================================================"
 echo -e "$COIN_NAME Masternode is up and running listening on port ${YELLOW}$COIN_PORT${NC}."
 echo -e "Configuration file is: ${YELLOW}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${YELLOW}systemctl start $COIN_NAME.service${NC}"
 echo -e "Stop: ${YELLOW}systemctl stop $COIN_NAME.service${NC}"
 echo -e "VPS_IP:PORT ${YELLOW}$NODEIP:$COIN_PORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${YELLOW}$COINKEY${NC}"
 echo -e "Please check ${YELLOW}$COIN_NAME${NC} daemon is running with the following command: ${YELLOW}systemctl status $COIN_NAME.service${NC}"
 echo -e "Use ${YELLOW}$COIN_CLI masternode status${NC} to check your MN. A running MN will show ${YELLOW}Status 9${NC}."
 echo -e "Use ${YELLOW}$COIN_CLI getinfo${NC} to check your info about your MN.${NC}."
echo -e "================================================================================================================================"
 
 
clear
 echo -e "{\"coin\":\""$COIN_NAME"\", \"port\":\""$COIN_PORT"\", \"id\":\""$NODEIP"\", \"mnip\":\""$NODEIP:$COIN_PORT"\", \"startmn\":\""$COIN_DAEMON -daemon"\", \"stopmn\":\""$COIN_CLI stop"\", \"getinfomn\":\""$COIN_CLI getinfo"\", \"statusmn\":\""$COIN_CLI masternode status"\", \"privatekey\":\""$COINKEY"\", \"startservice\":\""systemctl start $COIN_NAME.service"\", \"stopservice\":\""systemctl stop $COIN_NAME.service"\"}"

}
function setup_node() {
  get_ip
  create_config
  create_key
  update_config
  enable_firewall
  important_information
  configure_systemd
}
 
 
##### Main #####
clear
 
checks
prepare_system
download_node
setup_node
