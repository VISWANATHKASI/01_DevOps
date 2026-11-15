

# Find your actual EBS identifier
ls -l /dev/disk/by-id/ | grep Amazon_Elastic_Block_Store

#Example:
# nvme-Amazon_Elastic_Block_Store_vol0123456789abcdef

# Update these variables in the script:
EBS_DEVICE_ID="/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_volXXXXXXXX"

FORMAT_EBS="false"



================================================================================================================================================================================================








===========================================================================================================================================================================================


# to give access to my ip
sudo firewall-cmd --zone=jenkins-access --add-source=205.254.168.156/32 --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --zone=jenkins-access --list-all


# to remove access to my ip
sudo firewall-cmd --zone=jenkins-access --remove-source=205.254.168.156/32 --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --zone=jenkins-access --list-all


# to create the zone
sudo firewall-cmd --new-zone=devops-access --permanent
sudo firewall-cmd --permanent --zone=devops-access --set-target=ACCEPT
sudo firewall-cmd --reload


# to list all id address listed to zone
sudo firewall-cmd --zone=devops-access --list-all


# to give access to my ip
sudo firewall-cmd --zone=devops-access --add-source=205.254.168.156/32 --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --zone=devops-access --list-all


#to not allow the traffic
sudo firewall-cmd --permanent --zone=devops-access --set-target=REJECT
sudo firewall-cmd --reload
sudo firewall-cmd --zone=devops-access --list-all


# to delete the zone
sudo firewall-cmd --permanent --delete-zone=devops-access
sudo firewall-cmd --reload


# to list the zones
sudo firewall-cmd --permanent --get-zones




Error: [Errno 30] Read-only file system: '/etc/firewalld/zones/jenkins-access.xml'
==================================================================================
# Check if firewalld is sandboxed
systemctl show firewalld.service --property=ProtectSystem

#If it says ProtectSystem=yes or ProtectSystem=strict: Systemd is explicitly preventing firewalld from writing to its own configuration folder.
  sudo systemctl edit firewalld.service

  [Service]
  ProtectSystem=no

  sudo systemctl daemon-reload
  sudo systemctl restart firewalld.service

  sudo firewall-cmd --zone=jenkins-access --add-source=205.254.168.187/32 --permanent
  sudo firewall-cmd --reload
  sudo firewall-cmd --zone=jenkins-access --list-all
