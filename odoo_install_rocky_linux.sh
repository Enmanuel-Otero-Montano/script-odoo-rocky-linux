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
cat > /etc/odoo.conf << EOF
[options]
This is the password that allows database operations:
admin_passwd = $OE_SUPERADMIN
db_host = False
db_port = False
db_user = odoo
db_password = False
xmlrpc_port = 8069
logfile = /var/log/odoo/odoo.log
logrotate = True
addons_path = /opt/odoo/odoo/addons,/opt/odoo/odoo-custom-addons
EOF

#Create a Systemd Service Unit
cd /etc/systemd/system/odoo.service
cat > odoo.service << EOF
[Unit]
Description=Odoo
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=odoo
Group=odoo
ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

#Enable and start Odoo service
systemctl enable --now odoo.service

#Configure Linux Firewall
firewall-cmd --permanent --add-port=8069/tcp && firewall-cmd --reload
