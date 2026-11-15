

# 1. Stop Jenkins
systemctl stop jenkins

# 2. Create temporary mount directory
mkdir -p /mnt/jenkins-ebs

# Format the new EBS volume
# sudo mkfs.ext4 /dev/nvme1n1

# Verify filesystem
sudo blkid /dev/nvme1n1


# 3. Mount the verified EBS filesystem temporarily
mount /dev/nvme1n1 /mnt/jenkins-ebs


# Verify the mount
findmnt /mnt/jenkins-ebs


# 4. Copy existing Jenkins data
rsync -aHAX --numeric-ids \
  /var/lib/jenkins/ \
  /mnt/jenkins-ebs/


# Verify. Expected: No output.
rsync -aHAXn --numeric-ids \
  /var/lib/jenkins/ \
  /mnt/jenkins-ebs/
  

# 5. Verify copied data
du -sh /var/lib/jenkins
du -sh /mnt/jenkins-ebs

# 6. Flush data and unmount
sync
umount /mnt/jenkins-ebs

# verify
systemctl is-active jenkins
findmnt /mnt/jenkins-ebs
ls -ld /var/lib/jenkins

# verify below
lsblk -f
cat /etc/fstab
systemctl status jenkins --no-pager -l

# Mount your EBS volume
mount UUID=4dff3227-e926-4d4b-8d77-523e12fcd65a /mnt/jenkins-ebs

# Verify the mount
findmnt /mnt/jenkins-ebs
df -hT /mnt/jenkins-ebs
ls -lah /mnt/jenkins-ebs

# Compare both Jenkins directories
du -sh /var/lib/jenkins
du -sh /mnt/jenkins-ebs

ls -lah /var/lib/jenkins

# Verify whether both copies are identical
rsync -aHAXnci --dry-run /var/lib/jenkins/ /mnt/jenkins-ebs/

# Check existing mount configuration
grep -n 'jenkins-ebs\|/var/lib/jenkins' /etc/fstab

# Prepare the backup
mv /var/lib/jenkins /var/lib/jenkins.backup

# create an empty mount point:
mkdir -p /var/lib/jenkins

# Configure EBS to mount at Jenkins home
mount UUID=4dff3227-e926-4d4b-8d77-523e12fcd65a /var/lib/jenkins

# verify:
findmnt /var/lib/jenkins
df -hT /var/lib/jenkins
ls -lah /var/lib/jenkins

systemctl is-active jenkins
findmnt /var/lib/jenkins
df -hT /var/lib/jenkins
ls -lah /var/lib/jenkins

# Unmount the temporary EBS mount
umount /mnt/jenkins-ebs

# Preserve the original Jenkins directory


