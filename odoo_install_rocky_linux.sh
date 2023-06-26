#!/bin/bash

# Script for installing Odoo on Rocky Lunix 9.
# Author: Enmanuel Otero Montano
#--------------------------------------------------------------------------------------------------------------------
OE_VERSION="16.0"
OE_SUPERADMIN="admin"
echo Starting the installation
sleep 3
echo Updating software package
sudo dnf update -y
echo Installing Odoo Prerequsites
sudo dnf install -y wget tar gcc git libpq-devel python-devel openldap-devel
postgresql-setup --initdb --unit postgresql
systemctl enable --now postgresql
su - postgres -c "createuser -s odoo"
#--------------------------------------------------------------------------------------------------------------------
echo Installing WKHTMLTOX
cd /tmp
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox-0.12.6.1-2.almalinux9.x86_64.rpm
dnf localinstall -y wkhtmltox-0.12.6.1-2.almalinux9.x86_64.rpm
#--------------------------------------------------------------------------------------------------------------------
echo Installing Odoo
useradd -r -m -U -s /bin/bash -d /opt/odoo odoo
su - odoo
git clone https://www.github.com/odoo/odoo --depth 1 --branch $OE_VERSION /opt/odoo/odoo
#--------------------------------------------------------------------------------------------------------------------
echo Creating and activating a Python virtual environment for Odoo
cd ~
python -m venv venv
source venv/bin/activate
#--------------------------------------------------------------------------------------------------------------------
echo Upgrade pip "(Python Package Manager)"
pip install --upgrade pip
pip install -r /opt/odoo/odoo/requirements.txt
deactivate
#--------------------------------------------------------------------------------------------------------------------
echo Configuring installation
mkdir /opt/odoo/odoo-custom-addons

#Exit from odoo user shell
exit

#Create a log file for Odoo ERP and adjust file permissions
mkdir /var/log/odoo
touch /var/log/odoo/odoo.log
chown -R odoo: /var/log/odoo/

#Add following directives in file 'odoo.conf'
cd /etc
echo>> odoo.conf "[options]"
echo>> odoo.conf This is the password that allows database operations:
echo>> odoo.conf admin_passwd = $OE_SUPERADMIN
echo>> odoo.conf db_host = False
echo>> odoo.conf db_port = False
echo>> odoo.conf db_user = odoo
echo>> odoo.conf db_password = False
echo>> odoo.conf xmlrpc_port = 8069
echo>> odoo.conf logfile = /var/log/odoo/odoo.log
echo>> odoo.conf logrotate = True
echo>> odoo.conf addons_path = /opt/odoo/odoo/addons,/opt/odoo/odoo-custom-addons

#Create a Systemd Service Unit
cd /etc/systemd/system
echo>> odoo.service "[Unit]"
echo>> odoo.service Description=Odoo
echo>> odoo.service Requires=postgresql.service
echo>> odoo.service After=network.target postgresql.service

echo>> odoo.service "[Service]"
echo>> odoo.service Type=simple
echo>> odoo.service SyslogIdentifier=odoo
echo>> odoo.service PermissionsStartOnly = "true"
echo>> odoo.service User=odoo
echo>> odoo.service Group=odoo
echo>> odoo.service ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo.conf
echo>> odoo.service StandardOutput=journal+console

echo>> odoo.service "[Install]"
echo>> odoo.serviceWantedBy=multi-user.target

#Enable and start Odoo service
systemctl enable --now odoo.service

#Configure Linux Firewall
firewall-cmd --permanent --add-port=8069/tcp && firewall-cmd --reload