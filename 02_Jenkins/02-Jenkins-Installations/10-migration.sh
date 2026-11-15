

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

# 4. Copy existing Jenkins data
rsync -aHAX --numeric-ids \
  /var/lib/jenkins/ \
  /mnt/jenkins-ebs/

# 5. Verify copied data
du -sh /var/lib/jenkins
du -sh /mnt/jenkins-ebs

# 6. Unmount temporary mount
umount /mnt/jenkins-ebs
