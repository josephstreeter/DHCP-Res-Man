### Infrastructure
Terminal Server - Where the script is executed from
Utility Server - Hosts the script, required files, and the IIS root directory where the list files are created
DHCP Servers - Two server hosts with the DHCP role installed and configured for failover

#Setup<br>

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
