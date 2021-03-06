#!/bin/bash
#======================================================================================================================
#
#          FILE: install.sh
#
#   DESCRIPTION: Install
#
#          BUGS: https://github.com/goodrain/rainbond-install/issues
#
#     COPYRIGHT: (c) 2018 by the Goodrain Delivery Team.
#
#       LICENSE: Apache 2.0
#       CREATED: 03/30/2018 10:49:37 AM
#======================================================================================================================

[[ $DEBUG ]] && set -x

REPO_URL="https://github.com/goodrain/rainbond-install.git"

which_cmd() {
    which "${1}" 2>/dev/null || \
        command -v "${1}" 2>/dev/null
}

check_cmd() {
    which_cmd "${1}" >/dev/null 2>&1 && return 0
    return 1
}

APT="$(which_cmd apt)"
YUM="$(which_cmd yum)"

pkg(){
    echo "Install the prerequisite packages..."
    if [ ! -z "$YUM" ];then
        yum makecache fast -q
        yum install -y -q git ntpdate > /dev/null
    else
        apt-get update -q
        apt-get install -y -q git ntpdate apt-transport-https > /dev/null

    fi
    ntpdate 0.cn.pool.ntp.org > /dev/null
}

run(){
    pkg
    [ -d "$PWD/rainbond-install" ] && rm -rf $PWD/rainbond-install
    
    if [ "$1" == "dev" ];then
        git clone --depth 1 -b dev ${REPO_URL}
    else
        git clone --depth 1 ${REPO_URL}
    fi
    
    cd rainbond-install
    if [[ $1 == "help" ]];then
        ./setup.sh
        echo "cd $PWD;  ./setup.sh <args>"
    elif [[ $1 == "dev" ]];then
        ./setup.sh dev
    else
        ./setup.sh install
    fi
}
case $1 in
    dev)
        run dev
    ;;
    help)
        run help
    ;;
    * )
        run
    ;;
esac