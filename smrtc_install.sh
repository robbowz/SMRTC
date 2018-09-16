# SMRTC masternode install script
# Edited by Robbowz
VERSION="0.1"
NODEPORT='9887'
RPCPORT='19112'
DAEMON_BINARY="smrtc"

RED='\033[0;31m'

# Useful variables
declare -r DATE_STAMP="$(date +%y-%m-%d-%s)"
declare -r SCRIPT_LOGFILE="/tmp/smrtc_node_${DATE_STAMP}_out.log"
declare -r SCRIPTPATH=$( cd $(dirname ${BASH_SOURCE[0]}) > /dev/null; pwd -P )
declare -r WANIP=$(dig +short myip.opendns.com @resolver1.opendns.com)


function print_greeting() {
	echo -e "[0;35m smrtc masternode install script[0m\n"
}


function print_info() {
	echo -e "[0;35m Install script version:[0m ${VERSION}"
	echo -e "[0;35m Your ip:[0m ${WANIP}"
	echo -e "[0;35m Masternode port:[0m ${NODEPORT}"
	echo -e "[0;35m RPC port:[0m ${RPCPORT}"
	echo -e "[0;35m Date:[0m ${DATE_STAMP}"
	echo -e "[0;35m Logfile:[0m ${SCRIPT_LOGFILE}"
}


function checks() 
{
  if [[ $(lsb_release -d) != *16.04* ]]; then
    echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled."
    exit 1
  fi

  if [[ $EUID -ne 0 ]]; then
     echo -e "${RED}$0 must be run as root."
     exit 1
  fi

  if [ -n "$(pidof $DAEMON_BINARY)" ]; then
    echo -e "The smrtc daemon is already running. SMRTC does not support multiple masternodes on one host."
    NEW_NODE="n"
    clear
  else
    NEW_NODE="new"
  fi
}


function install_packages() {
	cd ~
	echo "Install packages..."
	sudo add-apt-repository -yu ppa:bitcoin/bitcoin  &>> ${SCRIPT_LOGFILE}
	sudo apt-get -y update &>> ${SCRIPT_LOGFILE}
	sudo apt-get -y install libzmq3-dev &>> ${SCRIPT_LOGFILE}
	sudo apt-get -y install wget make automake autoconf build-essential libtool autotools-dev \
	sudo git nano python-virtualenv pwgen virtualenv \
	pkg-config libssl-dev libevent-dev bsdmainutils software-properties-common \
	libboost-all-dev libminiupnpc-dev libdb4.8-dev libdb4.8++-dev &>> ${SCRIPT_LOGFILE}
	echo "Install done..."
}


function swaphack() {
	echo "Setting up disk swap..."
	free -h
	rm -f /var/smrtc_node_swap.img
	touch /var/smrtc_node_swap.img
	dd if=/dev/zero of=/var/smrtc_node_swap.img bs=1024k count=2000 &>> ${SCRIPT_LOGFILE}
	chmod 0600 /var/smrtc_node_swap.img
	mkswap /var/smrtc_node_swap.img &>> ${SCRIPT_LOGFILE}
	free -h
	echo "Swap setup complete..."
}


function remove_old_files() {
	echo "Removing old files..."
	sudo killall smrtcd
	sudo rm -rf /root/smrtc
	sudo rm -rf /root/.smrtc
    sudo rm -rf smrtcd
    sudo rm -rf smrtc-cli
	echo "Done..."
}


function download_wallet() {
	echo "Downloading wallet..."
	mkdir /root/smrtc
    cd smrtc
	mkdir /root/.smrtc
	wget https://github.com/telostia/smartcloud-guides/releases/download/0.001/smrtc-linux.tar.gz
	tar -xvf smrtc-linux.tar.gz
	rm -rf smrtc-linux.tar.gz/
	rm -rf /root/smrtc/smrtc-linux.tar.gz
	chmod +x /root/smrtc/
	chmod +x /root/smrtc/smrtcd
	chmod +x /root/smrtc/smrtc-cli
	echo "Done..."
}


function configure_firewall() {
	echo "Configuring firewall rules..."
	apt-get -y install ufw			&>> ${SCRIPT_LOGFILE}
	# disallow everything except ssh and masternode inbound ports
	ufw default deny			&>> ${SCRIPT_LOGFILE}
	ufw logging on				&>> ${SCRIPT_LOGFILE}
	ufw allow ssh/tcp			&>> ${SCRIPT_LOGFILE}
	ufw allow 9887/tcp			&>> ${SCRIPT_LOGFILE}
	ufw allow 19112/tcp			&>> ${SCRIPT_LOGFILE}
	# This will only allow 6 connections every 30 seconds from the same IP address.
	ufw limit OpenSSH			&>> ${SCRIPT_LOGFILE}
	ufw --force enable			&>> ${SCRIPT_LOGFILE}
	echo "Done..."
}


function configure_masternode() {
	echo "Configuring masternode..."
	conffile=/root/.smrtc/smrtc.conf
	PASSWORD=`pwgen -1 20 -n` &>> ${SCRIPT_LOGFILE}
	if [ "x$PASSWORD" = "x" ]; then
	    PASSWORD=${WANIP}-`date +%s`
	fi
	echo "Loading and syncing wallet..."
	echo "    if you see *error: Could not locate RPC credentials* message, do not worry"
	/root/smrtc/smrtc-cli stop
	echo "It's okay."
	sleep 10
	echo -e "rpcuser=smrtcuser\nrpcpassword=${PASSWORD}\nrpcport=${RPCPORT}\nrpcallowip=127.0.0.1\nport=${NODEPORT}\nexternalip=${WANIP}\nlisten=1\nmaxconnections=250" >> ${conffile}
	echo ""
	echo -e "[0;35m==================================================================[0m"
	echo -e "     DO NOT CLOSE THIS WINDOW OR TRY TO FINISH THIS PROCESS"
	echo -e "                        PLEASE WAIT 2 MINUTES"
	echo -e "[0;35m==================================================================[0m"
	echo ""
	/root/smrtc/smrtcd -daemon
	echo "2 MINUTES LEFT"
	sleep 60
	echo "1 MINUTE LEFT"
	sleep 60
	masternodekey=$(/root/smrtc/smrtc-cli masternode genkey)
	/root/smrtc/smrtc-cli stop
	sleep 20
	echo "Creating masternode config..."
	echo -e "daemon=1\nmasternode=1\nmasternodeprivkey=$masternodekey" >> ${conffile}
	echo "Done...Starting daemon..."
	/root/smrtc/smrtcd -daemon
}

function addnodes() {
	echo "Adding nodes..."
	conffile=/root/.smrtc/smrtc.conf
	echo -e "\naddnode=95.179.132.243" 	>> ${conffile}
	echo -e "addnode=108.61.165.133" 	>> ${conffile}
	echo -e "addnode=201.80.1.151" 	>> ${conffile}
    echo -e "addnode=95.179.140.3" 	>> ${conffile}
	echo -e "addnode=82.2.156.164" 	>> ${conffile}
    echo -e "addnode=173.249.51.26" 	>> ${conffile}
	echo -e "addnode=167.99.65.33\n" >> ${conffile}
	echo "Done..."
}


function show_result() {
	echo ""
	echo -e "[0;35m==================================================================[0m"
	echo "DATE: ${DATE_STAMP}"
	echo "LOG: ${SCRIPT_LOGFILE}"
	echo "rpcuser=smrtcuser"
	echo "rpcpassword=${PASSWORD}"
	echo ""
	echo -e "[0;35m INSTALLED WITH VPS IP: ${WANIP}:${NODEPORT} [0m"
	echo -e "[0;35m INSTALLED WITH MASTERNODE PRIVATE GENKEY: ${masternodekey} [0m"
	echo ""
	echo -e "If you get \"Masternode not in masternode list\" status, don't worry,\nyou just have to start your MN from your local wallet and the status will change"
	echo -e "[0;35m==================================================================[0m"
}


function cleanup() {
	echo "Cleanup..."
	apt-get -y autoremove 	&>> ${SCRIPT_LOGFILE}
	apt-get -y autoclean 		&>> ${SCRIPT_LOGFILE}
	echo "Done..."
}


#Setting auto start cron job for smrtcd
cronjob="@reboot sleep 30 && /root/smrtc/smrtcd"
crontab -l > tempcron
if ! grep -q "$cronjob" tempcron; then
    echo -e "Configuring crontab job..."
    echo $cronjob >> tempcron
    crontab tempcron
fi
rm tempcron


# Flags
compile=0;
swap=0;
firewall=0;


#Bad arguments
if [ $? -ne 0 ];
then
    exit 1
fi


# Check arguments
while [ "$1" != "" ]; do
    case $1 in
        -sw | --swap )
            swap=1
            ;;
        -f | --firewall )
            firewall=1
            ;;
        * )
            exit 1
    esac
    if [ "$#" -gt 0 ]; then shift; fi
done


# main routine
checks
if [[ "$NEW_NODE" == "new" ]]; then
  print_greeting
  print_info
  install_packages
else
    echo -e "${GREEN}The SMRTC daemon is already running. SMRTC does not support multiple masternodes on one host.${NC}"
  exit 0
fi

if [ "$swap" -eq 1 ]; then
	swaphack
fi

if [ "$firewall" -eq 1 ]; then
	configure_firewall
fi

remove_old_files
download_wallet
addnodes
configure_masternode

show_result
cleanup
echo "All done!"
cd ~/
sudo rm /root/smrtc_install.sh
