
# Check Jenkins version
jenkins --version

# Check Java version
java -version

# Verify automatic startup
systemctl is-enabled jenkins

# Verify EBS volume attachment and mount
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
# expected output is   nvme1n1        20G ext4     /var/lib/jenkins

# Verify Jenkins mount
findmnt /var/lib/jenkins
# expected output is  /var/lib/jenkins /dev/nvme1n1 ext4   rw,relatime

# Verify available volume capacity
df -hT /var/lib/jenkins
# expected output : /dev/nvme1n1   ext4   20G  187M   19G   1% /var/lib/jenkins


# Verify directory permissions
ls -ld /var/lib/jenkins


# Verify UUID configuration
grep '/var/lib/jenkins' /etc/fstab
# UUID=8cfc6830-ba20-492f-85b2-d3e2a20f2b74 /var/lib/jenkins ext4 defaults,nofail,x-systemd.device-timeout=30 0 2


# Verify Jenkins mount dependency
# cat /etc/systemd/system/jenkins.service.d/override.conf
systemctl cat jenkins
# expected output
[Unit]
RequiresMountsFor=/var/lib/jenkins


# Verify persistence after reboot
sudo reboot


#Run below again
findmnt /var/lib/jenkins
df -hT /var/lib/jenkins
grep -v '^[[:space:]]*#' /etc/fstab
systemctl is-active jenkins


# Check Jenkins logs
journalctl -u jenkins -n 50 --no-pager



