

SSH (Secure Shell) is a protocol used to securely connect to a remote Linux server over a network.


#OPEN THE DOWNLOADS DIRECTORY
cd Downloads


# Verify whether the PEM file exists
ls -l chandra-nv.pem


# Set private key permissions to 400 (read-only for the file owner).
chmod 400 chandra-nv.pem


#Execute the following SSH command:
ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no -p 22 -v -i chandra-nv.pem ec2-user@98.81.155.74   #-->Establishes a secure SSH connection. Specifies the identity (private key) file. EC2 instance private key file. Default username for Amazon Linux EC2 instances. Public IP address of the EC2 instance. 

ssh	            -->  Starts an SSH connection.
-p 22           -->  to use port 22 specifically
-v              --> Enables verbose mode to display detailed connection information for troubleshooting.
-i	            -->  Specifies the private key file.
chandra-nv.pem	-->  EC2 private key file.
ec2-user	      -->  Remote Linux username (Amazon Linux).
@	              -->  Separates username and hostname.
98.81.155.74	  -->  Public IP address of EC2.



# disconnect from the ec2 instance
exit
# OR press Ctrl + D


COMMON SSH CONNECTION ERRORS:
============================

+----------------------------+------------------------------------------+--------------------------------------------------+
| ERROR                      | POSSIBLE REASON                           | SOLUTION                                         |
+----------------------------+------------------------------------------+--------------------------------------------------+
| Permission denied          | Incorrect PEM file or username.          | Verify the correct private key and EC2          |
| (publickey)                |                                          | username (ec2-user, ubuntu, etc.).               |
+----------------------------+------------------------------------------+--------------------------------------------------+
| UNPROTECTED PRIVATE KEY    | Private key permissions are too open.    | Run:                                             |
| FILE                       |                                          | chmod 400 chandra-nv.pem                         |
+----------------------------+------------------------------------------+--------------------------------------------------+
| Connection timed out       | Port 22 is blocked or incorrect          | Check Security Group inbound rules,             |
|                            | public IP address.                       | Network ACLs, and EC2 public IP.                 |
+----------------------------+------------------------------------------+--------------------------------------------------+
| Connection refused         | SSH service may not be running or        | Check whether the SSH service is running        |
|                            | listening on port 22.                    | and listening on port 22.                        |
+----------------------------+------------------------------------------+--------------------------------------------------+
| No such file or directory  | PEM file not found in the current       | Verify the PEM file location and filename.      |
|                            | working directory.                       |                                                  |
+----------------------------+------------------------------------------+--------------------------------------------------+

