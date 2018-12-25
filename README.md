# DHCP Reservation Management
### Concept
All hosts in the environment are configured with a static IP address or assigned a DHCP reservation. Firewall rules for DHCP configured hosts are provisioned from separate lists of IP addresses that are consumed by the firewall. Hosts are grouped by type of host and entered into a list so that the firewall assigns the IPs to the appropriate set of rules. 

The IP lists are created by enumerating the DHCP reservations and grouping them by the data provided in the Description field. Because of the importance of having accurate description information the script will provide the consistency required for proper grouping. Through automating the creating, updating, deleting, and exporting of the DHCP reservations the possibility of human error is significantly reduced. 

### Infrastructure
Terminal Server - The host from which the script is executed <br>
Utility Server - Hosts the script, required files, and the IIS root directory where the list files are created <br>
DHCP Servers - Two server hosts with the DHCP role installed and configured for failover <br>

### Setup<br>

On the utility server create two CIF shares. One share represents the 
directory served by the web server to provide access to the list files
and the other will contain the script files and various output files. 

Example:<br>
\\\server\scripts\ <br>
\\\server\www <br>

Within the scripts share several sub-directories are required for archive,
logs, script modules, and the groups file. The script itself can be located
anywhere as long as it is in the same directory as the XML configuration 
file. Its would be recommended to leave the script and configuration file in 
the root of the scripts share.

\\\server\scripts\          <-- Script and configuration file<br>
\\\server\scripts\Archive\  <-- Contains archived list files<br> 
\\\server\scripts\Groups\   <-- Contains text file for group name validation<br>
\\\server\scripts\Logs\     <-- Contains log files created by script<br>
						
\\\Server\www\			  <-- Contains the list files and is the root dir for IIS<br>

These locations can be changed as long as the configuration script is updated.
