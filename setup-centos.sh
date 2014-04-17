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
/sbin/chkconfig --level 35 httpd on
/sbin/chkconfig --level 35 mysqld on

#
# Configure ROOT MySQL Password
#

mysqladmin -u root password sindbadmin


#
#Install Nagios
#

cd /usr/local/src/

archive_nagios="nagios-$nagios_version.tar.gz"
if [ ! -f $archive_nagios ]
then
	wget http://download.openology.net/project/si-nagios/sources/$archive_nagios
fi

tar xvzf $archive_nagios
cd nagios-$nagios_version/
./configure --prefix=/usr/local/nagios --with-nagios-user=nagios --with-nagios-group=nagios --with-command-user=nagios --with-command-group=nagcmd --enable-event-broker --enable-nanosleep --enable-embedded-perl --with-perlcache
make all install install-init install-commandmode install-config install-webconf
htpasswd -c /usr/local/nagios/etc/htpasswd.users sinadmin
/etc/init.d/httpd reload


#
#Install Nagios plugins
#

cd /usr/local/src/
archive_nagios_plugins="nagios-plugins-$nagios_plugins_version.tar.gz"
if [ ! -f $archive_nagios_plugins ]
then
	wget http://download.openology.net/project/si-nagios/sources/$archive_nagios_plugins
fi
	
tar xvzf $archive_nagios_plugins 
cd nagios-plugins-$nagios_plugins_version/
./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-command-user=nagios --with-command-group=nagcmd --prefix=/usr/local/nagios
make
make install

#
# Install NRPE
#

cd /usr/local/src/
archive_nrpe="nrpe-$nrpe_version.tar.gz"
if [ ! -f $archive_nrpe ]
then
	wget http://download.openology.net/project/si-nagios/sources/$archive_nrpe
fi

tar xvzf $archive_nrpe
chmod 755 -R nrpe-$nrpe_version
cd nrpe-$nrpe_version/
./configure --enable-ssl --with-ssl 
make all
make install
cp init-script.suse /etc/init.d/nrpe
chmod a+rx /etc/init.d/nrpe
cp sample-config/nrpe.cfg /usr/local/nagios/etc/


#
#Install NDO
#

cd /usr/local/src/
archive_ndoutils="ndoutils-$ndoutils_version.tar.gz"
if [ ! -f $archive_ndoutils ]
then
	wget http://download.openology.net/project/si-nagios/sources/$archive_ndoutils
fi
tar xvzf $archive_ndoutils 

#
# Installation du patch
#

cd ndoutils-$ndoutils_version
wget http://download.tech-max.fr/nagios/common/setup_files/ndoutils${ndoutils_version}_light.patch
patch -p1 -N < ndoutils${ndoutils_version}_light.patch
./configure --prefix=/usr/local/nagios/ --enable-mysql --disable-pgsql \
   --with-ndo2db-user=nagios --with-ndo2db-group=nagios
make
cp ./src/ndomod-3x.o /usr/local/nagios/bin/ndomod.o
cp ./src/ndo2db-3x /usr/local/nagios/bin/ndo2db
cp ./config/ndo2db.cfg-sample /usr/local/nagios/etc/ndo2db.cfg
cp ./config/ndomod.cfg-sample /usr/local/nagios/etc/ndomod.cfg
chmod 770 /usr/local/nagios/bin/ndo*
chown nagios:nagios /usr/local/nagios/bin/ndo*
cp ./daemon-init /etc/init.d/ndo2db
chmod +x /etc/init.d/ndo2db

#
# Install Centreon
#

cd /usr/local/src/
wget http://download.tech-max.fr/nagios/common/setup_files/centreon-$centreon_version.tar.gz
wget http://download.tech-max.fr/nagios/CentOS/centos.si
tar xvzf centreon-$centreon_version.tar.gz
cd centreon-$centreon_version/
export PATH="$PATH:/usr/local/nagios/bin/"
./install.sh -f /usr/local/src/centos.si
/etc/init.d/httpd reload

#
# Langue Centreon
#

# En toute rigueur il faudrait faire locale=$LANG mais on n'est pas sûr de trouver toutes
# les langues sur http://download.tech-max.fr/

lang="fr_FR"
locale="$lang.UTF-8"
centreon_lang_version="2.1-$lang-1"

mkdir -p /usr/local/centreon/www/locale/$locale/LC_MESSAGES/
cd /usr/local/src/
archive_nagios_lang="centreon-$centreon_lang_version.tgz"
if [ ! -f $archive_nagios_lang ]
then
	wget http://download.tech-max.fr/nagios/common/setup_files/$archive_nagios_lang
fi
tar xvzf $archive_nagios_lang 
#cd centreon-$centreon_lang_version/LC_MESSAGES
cd centreon-$centreon_lang_version.1/LC_MESSAGES
cp messages.mo /usr/local/centreon/www/locale/$locale/LC_MESSAGES/messages.mo
read -p "Se connecter à http://Ip/centreon, suivre les étapes de configuration de l'interface Centreon et à la fin appuyer sur une touche pour finaliser..."

#
# Ajout des services ndo2db, nagios, nrpe, snmp 
#

/sbin/chkconfig --level 35 snmpd on
/sbin/chkconfig --level 35 snmptrapd on
/sbin/chkconfig --level 35 ndo2db on
/sbin/chkconfig --level 01246 ndo2db off
/sbin/chkconfig --level 35 nagios on
/sbin/chkconfig --level 01246 nagios off
/sbin/chkconfig --level 35 nrpe on
/sbin/chkconfig --level 01246 nrpe off
/etc/init.d/ndo2db start
/etc/init.d/nagios start
/etc/init.d/nrpe start

#
# On vérifie que tout est OK
#

if [ $(grep -c "ndomod" /usr/local/nagios/var/nagios.log) -ne 0 ]
then
	grep ndomod /usr/local/nagios/var/nagios.log
fi
