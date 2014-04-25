#!/bin/bash

# Set variables
set -e
nagios_version="4.0.4"
nagios_patch="bogus_warnings.patch"
nagios_plugins_version="2.0"
nrpe_version="2.15"
ndoutils_version="2.0.0"
centreon_version="2.5.0"
package_list="httpd gd fontconfig-devel libjpeg-devel libpng-devel gd-devel perl-GD perl-Config-IniFiles perl-DBI perl-DBD-MySQL openssl-devel mysql-server mysql-devel php php-mysql php-gd php-ldap php-xml php-mbstring rrdtool perl-rrdtool perl-RRD-Simple perl-Crypt-DES perl-Digest-SHA1 perl-Digest-HMAC net-snmp-utils perl-Socket6 perl-IO-Socket-INET6 net-snmp net-snmp-libs php-snmp dmidecode lm_sensors perl-Net-SNMP net-snmp-perl mailx postfix fping graphviz cpp gcc gcc-c++ libstdc++ glib2-devel libtool-ltdl-devel php-pear postfix"
package_pear_list="SOAP Validate XML_RPC2 XML_RPC DB DB_DataObject DB_DataObject_FormBuilder Archive_Tar Archive_Zip Auth_SASL Auth_SASL2 Console_GetoptPlus Date HTML_Common2 HTML_QuickForm2 HTML_QuickForm_advmultiselect HTML_Table HTTP_Request2 Image_GraphViz Log MDB2 Net_Ping Net_SMTP Net_Socket Net_Traceroute Net_URL2 Structures_Graph"

# Add RPM Forge repository
cd /usr/local/src/
if [[ ! -f /etc/yum.repos.d/rpmforge.repo ]]
	then
	wget http://download.openology.net/nagios/CentOS/rpmforge-release-0.5.3-1.el6.rf.x86_64.rpm
	rpm --import http://apt.sw.be/RPM-GPG-KEY.dag.txt
	rpm -K rpmforge-release-0.5.3-1.el6.rf.*.rpm
	rpm -i rpmforge-release-0.5.3-1.el6.rf.*.rpm
fi

# Dependencies installation
yum install -y $package_list

# PHP-PEAR Update
pear channel-update pear.php.net
pear upgrade pear
pear upgrade-all
pear install -f $package_pear_list

# Create nagcmd group
if [ $(grep -c "^nagcmd:" /etc/group) -eq 0 ]
	then
		groupadd nagcmd
	fi
# Create nagios group
if [ $(grep -c "^nagios:" /etc/group) -eq 0 ]
	then
		groupadd nagios
	fi

# Create nagios user
if [ $(grep -c "^nagios:" /etc/passwd) -eq 0 ]
	then
		useradd --home /usr/local/nagios --gid nagios --groups nagcmd  nagios
	fi

#Adding apache user to nagios and nagcmd groups
/usr/sbin/usermod -G nagios,nagcmd apache

# Starting basic services
/etc/init.d/httpd start
/etc/init.d/mysqld start

# Configure ROOT MySQL Password
mysqladmin -u root password sinadmin

#Install Nagios
cd /usr/local/src/
archive_nagios="nagios-$nagios_version.tar.gz"
if [ ! -f $archive_nagios ]
	then
		wget http://download.openology.net/project/sinagios/sources/$archive_nagios
	fi
if [ ! -f $nagios_patch ]
	then
		wget http://download.openology.net/project/sinagios/sources/$nagios_patch
	fi
tar xzf $archive_nagios
cd nagios-$nagios_version/
patch -p1 -N < /usr/local/src/bogus_warnings.patch
./configure --prefix=/usr/local/nagios --with-command-group=nagcmd --enable-nanosleep --enable-event-broker
make all install install-init install-commandmode install-config install-webconf
htpasswd -cb /usr/local/nagios/etc/htpasswd.users nagiosadmin nagiosadmin

#Install Nagios plugins
cd /usr/local/src/
archive_nagios_plugins="nagios-plugins-$nagios_plugins_version.tar.gz"
if [ ! -f $archive_nagios_plugins ]
	then
		wget http://download.openology.net/project/sinagios/sources/$archive_nagios_plugins
	fi
tar xzf $archive_nagios_plugins 
cd nagios-plugins-$nagios_plugins_version/
./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-openssl=/usr/bin/openssl
make
make install

## Install NRPE
cd /usr/local/src/
archive_nrpe="nrpe-$nrpe_version.tar.gz"
if [ ! -f $archive_nrpe ]
	then
		wget http://download.openology.net/project/sinagios/sources/$archive_nrpe
	fi
tar xzf $archive_nrpe
cd nrpe-$nrpe_version/
./configure --with-ssl=/usr/bin/openssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu
make all
make install
cp init-script.debian /etc/init.d/nrpe
chmod a+rx /etc/init.d/nrpe
cp sample-config/nrpe.cfg /usr/local/nagios/etc/

#Install NDO
cd /usr/local/src/
archive_ndoutils="ndoutils-$ndoutils_version.tar.gz"
if [ ! -f $archive_ndoutils ]
	then
		wget http://download.openology.net/project/sinagios/sources/$archive_ndoutils
	fi
tar xzf $archive_ndoutils 
cd ndoutils-$ndoutils_version
./configure --prefix=/usr/local/nagios/ --enable-mysql --disable-pgsql --with-ndo2db-user=nagios --with-ndo2db-group=nagios
make
cp ./src/ndomod-4x.o /usr/local/nagios/bin/ndomod.o
cp ./src/ndo2db-4x /usr/local/nagios/bin/ndo2db
cp ./config/ndo2db.cfg-sample /usr/local/nagios/etc/ndo2db.cfg
cp ./config/ndomod.cfg-sample /usr/local/nagios/etc/ndomod.cfg
chmod 770 /usr/local/nagios/bin/ndo*
chown nagios:nagios /usr/local/nagios/bin/ndo*
cp ./daemon-init /etc/init.d/ndo2db
chmod +x /etc/init.d/ndo2db

# Install Centreon
cd /usr/local/src/
archive_centreon="centreon-$centreon_version.tar.gz"
if [ ! -f $archive_centreon ]
	then
	wget http://download.openology.net/project/sinagios/sources/centreon-$centreon_version.tar.gz
	fi
tar xzf centreon-$centreon_version.tar.gz
cd centreon-$centreon_version/
./install.sh -i

# Post-Install configuration
/sbin/chkconfig --level 35 httpd on
/sbin/chkconfig --level 35 mysqld on
/sbin/chkconfig --level 35 snmpd on
/sbin/chkconfig --level 35 snmptrapd on
/sbin/chkconfig --level 35 ndo2db on
/sbin/chkconfig --level 01246 ndo2db off
/sbin/chkconfig --level 35 nagios on
/sbin/chkconfig --level 01246 nagios off
/sbin/chkconfig --level 35 nrpe on
/sbin/chkconfig --level 01246 nrpe off
/etc/init.d/httpd restart
sed 's/\[mysqld\]/[mysqld]\ninnodb_file_per_table=1/' /etc/mysql/my.cnf
service mysqld restart
service ndo2db start
service nagios start
service nrpe start

 Check everything is OK
if [ $(grep -c "ndomod: Could not open data sink\!" /usr/local/nagios/var/nagios.log) -ne 0 ]
	then
		grep ndomod /usr/local/nagios/var/nagios.log
fi
read -p "Se connecter à http://Ip/centreon, suivre les étapes de configuration de l'interface Centreon et à la fin appuyer sur une touche pour finaliser..."