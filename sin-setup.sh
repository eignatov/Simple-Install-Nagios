#!/bin/bash
#chmod +x nagcent
reset
echo "       ###############   ###   ####        ###";
echo "      ###############   ###   ### ##      ###";
echo "     ###               ###   ###  ##     ###";
echo "    ###############   ###   ###   ##    ###";
echo "   ###############   ###   ###    ##   ###";
echo "              ###   ###   ###     ##  ###";
echo " ###############   ###   ###      ## ###";
echo "###############   ###   ###        ####";
echo "";
echo "What is the distribution used ?";
echo "";
echo "1) For distribution based on Debian (Debian, Ubuntu...";
echo "2) For distribution based on RHEL (CentOS, Fedora...";
read answer
if [ $answer = "1" ] || [ $answer = "DEBIAN" ]
then
cd /usr/local/src/ 
wget http://download.openology.net/project/sinagios/os/setup-debian.sh
chmod +x setup-debian.sh
./setup-debian.sh
else
cd /usr/local/src/ 
wget http://download.openology.net/project/sinagios/os/setup-centos.sh
chmod +x setup-centos.sh
./setup-centos.sh
fi
