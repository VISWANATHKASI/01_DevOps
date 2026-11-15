
# Stop Jenkins
sudo systemctl stop jenkins

# Confirm it stopped:
systemctl is-active jenkins

# Identify and prepare EBS
lsblk -f

# Check its UUID:
sudo blkid /dev/nvme1n1
# Expected filesystem: TYPE="ext4" UUID="4dff3227-e926-4d4b-8d77-523e12fcd65a"

# Only for a brand-new, empty EBS volume without a filesystem, formatting would be:
# sudo mkfs.ext4 /dev/nvme1n1

# Mount EBS temporarily
sudo mkdir -p /mnt/jenkins-ebs

# Mount the volume:
sudo mount UUID=4dff3227-e926-4d4b-8d77-523e12fcd65a /mnt/jenkins-ebs

# Verify:
findmnt /mnt/jenkins-ebs
df -hT /mnt/jenkins-ebs

# Copy Jenkins data to EBS
sudo rsync -aHAX --numeric-ids \
  /var/lib/jenkins/ \
  /mnt/jenkins-ebs/

# Verify the copy:
sudo rsync -aHAXnci --dry-run \
  /var/lib/jenkins/ \
  /mnt/jenkins-ebs/
# Expected: no output if there are no differences.

# Compare directory sizes:
sudo du -sh /var/lib/jenkins
sudo du -sh /mnt/jenkins-ebs

# Flush data and unmount temporary location
sudo sync
sudo umount /mnt/jenkins-ebs

# Backup original Jenkins directory
sudo mv /var/lib/jenkins /var/lib/jenkins.backup

# Create the permanent mount point:
sudo mkdir -p /var/lib/jenkins

# Mount EBS permanently at Jenkins home
sudo mount UUID=4dff3227-e926-4d4b-8d77-523e12fcd65a /var/lib/jenkins

# Configure automatic mounting using fstab
cp -a /etc/fstab /etc/fstab.backup 
grep -qxF "UUID=4dff3227-e926-4d4b-8d77-523e12fcd65a /var/lib/jenkins ext4 defaults,nofail 0 2" /etc/fstab || echo "UUID=4dff3227-e926-4d4b-8d77-523e12fcd65a /var/lib/jenkins ext4 defaults,nofail 0 2" >> /etc/fstab

# Configure Jenkins startup dependency
sudo systemctl edit jenkins
#Add:
[Unit]
RequiresMountsFor=/var/lib/jenkins

# Reload systemd:
sudo systemctl daemon-reload

# Verify permissions
ls -ld /var/lib/jenkins
# Expected ownership: jenkins jenkins
# sudo chown -R jenkins:jenkins /var/lib/jenkins

# Validate and start Jenkins
# Validate fstab:
sudo mount -a
# Check EBS:
findmnt /var/lib/jenkins
# Check available space:
df -hT /var/lib/jenkins

# Start Jenkins:
sudo systemctl start jenkins

# Check service:
sudo systemctl status jenkins --no-pager -l

# Check active state:
systemctl is-active jenkins

# Reboot the EC2 instance:
sudo reboot

# After reconnecting through SSH
sudo mount -a
mountpoint /var/lib/jenkins
findmnt /var/lib/jenkins
systemctl is-active jenkins

# Remove backup after successful validation
# sudo rm -rf /var/lib/jenkins.backup



