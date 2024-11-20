
packspread.sh
packspread.sh is a Bash script designed to streamline package management tasks across multiple machines. It supports local and remote package installation and removal, ensuring synchronized package management in a networked environment.

Features
Local and Remote Package Management: Installs or removes packages on the local machine and a set of predefined remote machines.
Error Handling: Provides detailed error messages, retry logic, and logging for troubleshooting.
System Status Check: Reports system restart requirements and uptime after package operations.
Robust SSH Verification: Ensures connectivity and permissions before performing remote operations.
Logging: Logs operations and errors to specific files for easy reference.
Prerequisites
Before using this script, ensure the following:

Dependencies:

Installed on all target machines: ssh, scp, md5sum, sudo, apt-get.
RSA Key Authentication:

Ensure RSA keys are configured for passwordless SSH access to all remote machines.
Remote Machine Configuration:

The script targets the following remote IPs:
192.168.1.145
192.168.1.248
192.168.1.238
User Account:

The script uses the username ageorge by default. Update this if necessary.
Usage
Syntax
bash
Copy code
./packspread.sh {install|remove} package1 [package2 ...]
Examples
Install a Package:

bash
Copy code
./packspread.sh install vim
Install Multiple Packages:

bash
Copy code
./packspread.sh install vim git curl
Remove a Package:

bash
Copy code
./packspread.sh remove vim
Remove Multiple Packages:

bash
Copy code
./packspread.sh remove vim git curl
Logging
Log Files:

Operation logs: /tmp/packspread_log.txt
Packspread-specific logs: /home/ageorge/.local_update_logs/Packspread.log
Restart Requirements:

The script will notify if a system restart is required and display the packages necessitating a restart.
Error Handling
Errors during operations trigger detailed logs and backtraces.
Retried operations are attempted up to three times before failing.
In case of errors, a cleanup function ensures resources are handled properly.
Custom Signals
Restart Script (SIGHUP):

Automatically restarts the script upon receiving the SIGHUP signal.
Custom Action (SIGUSR1):

Reloads the exclusions configuration file at /home/ageorge/Desktop/Update-Script/exclusions_config.
Notes
Default Configuration: The script is pre-configured with default file paths, usernames, and remote IPs. Update these variables in the script if necessary.
Validation: The script validates all required commands and SSH connectivity before performing actions.
Troubleshooting
SSH Verification Failure:

Ensure the remote machine is reachable and SSH is enabled.
Verify that the RSA keys are correctly configured for passwordless login.
Command Not Found:

Make sure the required commands (ssh, scp, md5sum, etc.) are installed on all target machines.
License
This script is provided as-is under an open-source license. Contributions and modifications are welcome.

