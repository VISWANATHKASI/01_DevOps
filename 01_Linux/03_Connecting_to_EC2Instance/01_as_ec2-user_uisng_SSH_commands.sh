

SSH (Secure Shell) is a protocol used to securely connect to a remote Linux server over a network.

#OPEN THE DOWNLOADS DIRECTORY
cd Downloads


#Set the private key file permissions to 400 so that only the file ownercan read it.
chmod 400 chandra-nv.pem  # SSH requires the private key to have restricted permissions. Otherwise,it may reject the key with an UNPROTECTED PRIVATE KEY FILE warning.


#Execute the following SSH command:
ssh -i chandra-nv.pem ec2-user@98.81.155.74   #-->Establishes a secure SSH connection. Specifies the identity (private key) file. EC2 instance private key file. Default username for            
                                                      Amazon Linux EC2 instances. Public IP address of the EC2 instance. 

# disconnect from the ec2 instance
exit or Ctrl + D #Both methods terminate the SSH session and return you to your localterminal.



COMMON SSH CONNECTION ERRORS:
=============================
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

