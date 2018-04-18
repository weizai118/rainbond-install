#!/bin/bash
NODE_HOSTNAME=
SYS_NAME=$(grep "^ID=" /etc/os-release | awk -F = '{print $2}'|sed 's/"//g')
SYS_VER=$(grep "^VERSION_ID=" /etc/os-release | awk -F = '{print $2}'|sed 's/"//g')
CPU_NUM=$(grep "processor" /proc/cpuinfo | wc -l )
MEM_SIZE=$(free -h | grep Mem | awk '{print $2}' | cut -d 'G' -f1 | awk -F '.' '{print $1}')
if [ "$SYS_NAME" == "centos" ];then
    DNS_INFO="^DNS"
    NET_FILE="/etc/sysconfig/network-scripts"
    INSTALL_BIN="yum"
else
    DNS_INFO="dns-nameservers"
    NET_FILE="/etc/network/interfaces"
    INSTALL_BIN="apt"
fi

function Initialize_Package(){
  $INSTALL_BIN install -y -q net-tools
}

function Set_Hostname(){
  inet_ip=$(ip ad | grep 'inet ' | egrep ' 10.|172.|192.168' | awk '{print $2}' | cut -d '/' -f 1 | grep -v '172.30.42.1' | head -1)
  hostname $NODE_HOSTNAME
  echo "$NODE_HOSTNAME" > /etc/hostname
  echo "$inet_ip $NODE_HOSTNAME" >> /etc/hosts
}

# check net
function Net_Test(){
curl -s --connect-timeout 3 https://www.rainbond.com -o /dev/null 2>/dev/null
if [ $? -eq 0 ];then
    return 0
else
    echo "Unable to connect to internet."
    exit 1
fi
}

# check system_version
function System_Version(){
  case $SYS_NAME in
  "centos")
    [ "$SYS_VER" == "7" ] \
    && return 0 \
    || ( echo "$SYS_NAME:$SYS_VER is not supported temporarily." && exit 1 )
    ;;
  "ubuntu")
    [ "$SYS_VER" == "16.04" ] \
    && return 0 \
    || ( echo "$SYS_NAME:$SYS_VER is not supported temporarily." && exit 1 )
    ;;
  "debian")
    [ "$SYS_VER" == "8" -o "$SYS_VER" == "9" ] \
    && return 0 \
    || ( echo "$SYS_NAME:$SYS_VER is not supported temporarily." && exit 1 )
    ;;
  *)
    echo "$SYS_NAME:$SYS_VER is not supported temporarily."
    exit 1
    ;;
  esac
}

# check cpu mem
function Check_Hardware(){
    if [ $CPU_NUM -lt 2 ] || [ $MEM_SIZE -lt 4 ];then
      echo "We need 2 CPUS, 4G Memories. But you Have $CPU_NUM CPUS,$MEM_SIZE G Memories"
      exit 1
    fi
}

# check docker
function Check_Docker(){
    if $(which docker >/dev/null 2>&1);then
        echo "Rainbond integrated customized docker, Please uninstall it first."
        exit 1
    else
        return 0
    fi
}
# check netcard

function Check_Netcard(){
  eths=$(ls -1 /sys/class/net|grep -v lo)
  for eth in $eths
  do
    ipaddr=$(ip addr show $eth | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
    if [ "$ipaddr" != "" ];then
      if [ "$SYS_NAME" == "centos" ];then
        check_netcard_base $NET_FILE/ifcfg-$eth $ipaddr \
        && return 0
      else
        check_netcard_base $NET_FILE $ipaddr \
        && return 0
      fi
    fi
  done
}

function check_netcard_base(){
  net_file=$1
  ipaddr=$2
  if [ -f $net_file ];then
    isStatic=$(grep "static" $net_file | grep -v "#")
    isIPExist=$(grep "$ipaddr" $net_file | grep -v "#")
    isDNSExist=$(grep "$DNS_INFO" $net_file | grep -v "#")
    
  if [ "$isStatic" != "" ] || [ "$isIPExist" != "" ] ;then
    return 0
  fi
  if [ "$isDNSExist" == "" ];then
    return 0
  fi
  else
    echo "There is no network config file, Next..."
  fi
}
Initialize_Package

Set_Hostname && echo "hostname is set to $NODE_HOSTNAME"

Net_Test && echo "net is ok"

System_Version && echo "system is ok"

Check_Hardware && echo "cpu、mem is ok"

Check_Docker && echo "docker isn't install"

Check_Netcard && echo "there is static card and no dns config" || exit 1