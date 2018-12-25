# Load Functions

function validate-IPAddress($data)
    {
    $test="^(?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)$"
    $results = $data -match $test
    Return $results
    }

function validate-HWAddress($data)
    {
    $test="^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
    $results = ($data -match $test) -or ($data -eq "Auto")
    Return $results
    }   
    
function validate-Groups($data)
    {
    $test=Get-Content "$GroupLocation\groups.txt"
    $results = $data -match $test
    Return $results
    }

function validate-Scope($data)
    {
    $Test=Get-DhcpServerv4Scope -ComputerName $DHCPServer -ScopeId $data -ErrorAction SilentlyContinue
    if ($test)
        {
        $results=$true
        }
    Else
        {
        $results=$false
        }

    Return $results
    }

function Generate-MacAddress()
    {
    $results=(0..5 | ForEach-Object { '{0:x}{1:x}' -f (Get-Random -Minimum 0 -Maximum 15),(Get-Random -Minimum 0 -Maximum 15)})  -join '-'
    Return $results
    }

Function Get-Group()
    {
    $groups=Get-Content "$groupLocation\groups.txt"
    $i=0
    $Groups | % {write-host "$i $_" ; $i++ }
    $Response=Read-Host "Enter group number"
    
    Return $groups[$Response]
    }

function Create-XMLFile($Path)
    {
    Try {Get-Item $path -ea stop}
    Catch {"Config file path cannot be found";Show-error;break}

    $XmlWriter = New-Object System.XMl.XmlTextWriter($Path,$Null)

    $xmlWriter.Formatting = 'Indented'
    $xmlWriter.Indentation = 1
    $XmlWriter.IndentChar = "`t"

    $xmlWriter.WriteStartDocument()
    $XmlWriter.WriteStartElement('Script')

    $xmlWriter.WriteStartElement('Config')
    $xmlWriter.WriteElementString('DHCPServer',"Host_name")
    $XmlWriter.WriteElementString('Lists',"Lists_Path")
    $XmlWriter.WriteElementString('Groups',"Groups_Path")
    $XmlWriter.WriteElementString('Logs',"Logs_Path")
    $XmlWriter.WriteElementString('Archive',"Archive_Path")
    $XmlWriter.WriteElementString('Module',"Module_Path")
    $xmlWriter.WriteEndElement() # close the "Config" node:

    $xmlWriter.WriteEndElement() # close the "Script" node:
    $xmlWriter.WriteEndDocument() # finalize the document:
    
    $xmlWriter.Finalize
    $xmlWriter.Flush()
    $xmlWriter.Close()
    }

function Import-Config()
    {
    $ConfigFile="\\PCI-UTIL-A1\DHCP\ConfigFile.xml"
    #$ConfigFile="\\192.168.0.101\scripts\ConfigFile.xml"
    if (-not (get-item $ConfigFile -ea SilentlyContinue))
        {
        Create-XMLFile $ConfigFile
        }

    if (get-item $ConfigFile -ea SilentlyContinue)
        {
        $Global:Config = [xml](Get-Content $ConfigFile -ea Stop)
        }
    Else
        {
        "Config file could not be loaded"
        Pause
        }
    }

Function Configure-ScriptMenu()
    {
    Import-Config
    Clear-Host
    "Configure Script:"
    "`t1 - Configure DHCP Server - $($config.script.config.DHCPServer)"
    "`t2 - Configure List Path - $($config.script.config.Lists)"
    "`t3 - Configure Group Path - $($config.script.config.Groups)"
    "`t4 - Configure Archive Path - $($config.script.config.Archive)"
    "`t5 - Configure Log Path - $($config.script.config.Logs)"
    "`t6 - Configure Module Path - $($config.script.config.Module)"
    "`tq - Quit"
    $Respose=Read-Host "Enter option to configure"

    Switch ($Respose)
        {
        1 {$config.script.config.DHCPServer=$(Read-Host "Enter DHCP Server name or IP address").ToString()}
        2 {$config.script.config.Lists=$(Read-Host "Enter path to List files").ToString()}
        3 {$config.script.config.Groups=$(Read-Host "Enter path to the Group file").ToString()}
        4 {$config.script.config.Archive=$(Read-Host "Enter path to Archive files").ToString()}
        5 {$config.script.config.Logs=$(Read-Host "Enter path to Log files").ToString()}
        6 {$config.script.config.Module=$(Read-Host "Enter path to Module").ToString()}
        q {Show-information}
        }

    Configure-ScriptMenu
    }

Function Edit-FilterLists()
    {
    Param(
    [Parameter(Mandatory=$True)][string]$list,
    [Parameter(Mandatory=$True)][string]$Action,
    [Parameter(Mandatory=$True)][ValidateScript({validate-data -data $_ -type MAC})][string]$mac,
    [Parameter(Mandatory=$True)][string]$HostName
    )
    $DHCPServers=(Get-DhcpServerInDC).DNSName      
    
    Foreach ($DHCPServer in $DHCPServers)
        {
        if ($Action -eq "Add")
            {
            $res=Get-DhcpServerv4Filter -ComputerName $DHCPServer -List Allow | ? {$_.macaddress -eq $mac} 
            if ($res){"Mac filter exists"}
            Else {Add-DhcpServerv4Filter -ComputerName $DHCPServer -List $List -MacAddress $mac -Description $HostName -Verbose}
            }
        Elseif ($Action -eq "Remove")
            {
            $res=Get-DhcpServerv4Filter -ComputerName $DHCPServer -List Allow | ? {$_.macaddress -eq $mac} 
            if ($res){remove-DhcpServerv4Filter -ComputerName $DHCPServer -MacAddress $mac -Verbose}
            Else {"No mac filter to remove"}
            }
        Else
            {
            "Improper action specified"
            }
        }
    }

function Replicate-Reservation()
    {
    Invoke-DhcpServerv4FailoverReplication -ComputerName $DHCPServer -Force
    Pause
    }

function Archive-Lists($source,$Destination)
    {
    $datetime = $(get-date -uformat "%Y-%m-%d-%H:%m:%S").Replace(":","-")
    $src="$source\*"
    $dst="$Destination\archive-$($datetime).zip"
    
    if ((Get-ChildItem $src).count -ge 1)
        {
        Compress-Archive -Path $Src -DestinationPath $Dst -Force
        if (Get-Item $dst -ea SilentlyContinue)
            {
            "Archive Complete"
            Remove-Item $src -Exclude web.config -Force
            }
        Else
            {
            "Archive Failed"
            Pause            
            }
        }
    }

Function Log-Event($EntryType,$Entry)
    {
    $date = get-date -uformat "%Y-%m-%d"
    $datetime = get-date -uformat "%Y-%m-%d-%H:%m:%S"
    $Logfile = $logDir+$date+"-logfile.txt"
    
    if (get-item $Logfile -ea 0)
        {
        $DateTime+"-"+$EntryType+"-"+$Entry | Out-File $Logfile -Append
        }
    Else
        {
        $DateTime+"-"+$EntryType+"-"+$Entry | Out-File $Logfile
        }
    }

function show-error($data)
    {
    Write-Host "Line: $($data.InvocationInfo.ScriptLineNumber) Character: $($error[0].InvocationInfo.OffsetInLine) $($error[0].InvocationInfo.Line.Trim()) $($error[0].CategoryInfo.Category) $($error[0].CategoryInfo.Reason)" -fore white -back red
    Pause
    }

Function Show-Information() 
    {
    Import-Config
    
    $Global:DHCPServer=$Config.Script.Config.DHCPServer
    $Global:GroupLocation=$Config.Script.Config.Groups
    $Global:FileLocation=$Config.Script.Config.Lists
    $Global:ArchiveLocation=$Config.Script.Config.Archive
    $Global:ModuleLocation=$Config.Script.Config.Module
    
    if ($?){Clear-Host}
    "********************************************************"
    "*       DHCP reservation Management tasks              *"
    "*                                                      *"
    "********************************************************"

    "`t1 - New Reservation"
    "`t2 - Edit Reservation"
    "`t3 - Remove Reservation"
    "`t4 - Export Reservations"
    "`t5 - Find Reservations"
    "`t6 - Replicate Scopes"
    ""
    "`tC - Configure"
    "`tQ - Quit"
        
    $Choice = Read-Host "`nSelect task"

    Switch ($Choice) {
        1 {New-Reservation}
        2 {Edit-Reservation}
        3 {Remove-Reservation}
        4 {Export-Reservation}
        5 {find-Reservation}
        6 {Replicate-Reservation}
        c {Configure-ScriptMenu}
        q {Break}
        Default {Show-Information}
        }
    ""
    if ($choice -ne "q")
        {
        pause
        Show-Information
        }
    }
 
################################################

function New-Reservation()
    {
    #List Scopes
    Get-DhcpServerv4Scope -ComputerName $DHCPServer | Select scopeID,Name,StartRange,EndRange | ft -AutoSize
    
    do {$scope=Read-Host "Enter Scope ID"} until (validate-scope $scope)
    do {$ip=Read-Host "Enter Reservation IP"} until (validate-IPAddress $ip)
    do {$mac=Read-Host "Enter MAC Address (aa-ab-ac-a2-a3-a4)"} until (validate-HWAddress $mac)
    $Hostname=Read-Host "Enter Reservation hostname"
    $group=$(Get-Group)

    $results=@()
    $results=New-Object psobject -Property @{
                                            "scope"=$scope
                                            "ip"=$ip
                                            "group"=$group
                                            "mac"=if ($mac -eq "auto"){Generate-MacAddress}Else{$mac}
                                            "Hostname"=$hostname
                                            }
    $results | ft -AutoSize

    $response=Read-Host "Is this information correct? (Y/N)"
    if ($response -eq "N"){Show-Information}

    $res=Get-DhcpServerv4Scope -ComputerName $DHCPServer -ea SilentlyContinue | % {Get-DhcpServerv4Reservation -ComputerName $DHCPServer -ScopeId $_.scopeid -ErrorAction SilentlyContinue} | `
        ? {($_.name -eq $hostname) -or ($_.ipaddress -eq $ip) -or ($_.clientid -eq $mac)}

    if ($res)
        {
        Write-Host "Reservation exists"
        pause
        Show-Information
        }
    Else
        {
        try {
            Add-DhcpServerv4Reservation `
                -ComputerName $DHCPServer `
                -ScopeId $results.scope `
                -IP $results.ip `
                -Description $results.group `
                -hostname $results.hostname `
                -ClientId $results.mac `
                -ea stop
            }
        Catch 
            {
            Show-Error $error[0]
            Show-Information
            }
        }

        try
            {
            Edit-FilterLists -list allow -Action add -mac $results.mac -HostName $results.hostname
            }
        catch
            {
            Show-Error $error[0]
            Show-Information
            }
    Replicate-Reservation
    }

Function Remove-Reservation()
    {
    $data=Read-Host "Enter reservation information"
        
    $res=Get-DhcpServerv4Scope -ComputerName $DHCPServer -ea SilentlyContinue | % {Get-DhcpServerv4Reservation -ComputerName $DHCPServer -ScopeId $_.scopeid -ErrorAction SilentlyContinue} | `
    ? {($_.name -eq $data) -or ($_.ipaddress -eq $data) -or ($_.clientid -eq $data)}
    
    $res | ft -AutoSize

    If ($(Read-Host "Confirm deletion? (y/n)") -eq "y")
        {
        Archive-Lists $FileLocation $FileLocation
        $res | Remove-DhcpServerv4Reservation -ComputerName $DHCPServer
        $res | % {Edit-FilterLists -list allow -Action remove -mac $_.ClientID -HostName $_.name}
        
        Replicate-Reservation
        }
   Else
        {
        "No reservation to remove"
        }
            
    }

Function Edit-Reservation()
    {
    $data=Read-Host "`nEnter reservation information (enter 'q' to quit)"
    if ($data -eq "q"){Show-Information}
    
    $res=Get-DhcpServerv4Scope -ComputerName $DHCPServer -ea SilentlyContinue | % {Get-DhcpServerv4Reservation -ComputerName $DHCPServer -ScopeId $_.scopeid -ErrorAction SilentlyContinue} | `
    ? {($_.name -eq $data) -or ($_.ipaddress -eq $data) -or ($_.clientid -eq $data)}

    if (-not($res))
        {
        "Reservation not found`n"
        Edit-Reservation
        }

    $res | ft -AutoSize

    "`t1 - MAC Address"
    "`t2 - Host Name"
    "`t3 - Group"
    ""    
    $Response=Read-Host "Select attribute to update"
    
    Archive-Lists $FileLocation $FileLocation

    switch ($Response)
        {
        1 {$NewMac=read-host "Enter new mac address"
            if ($mac -eq "auto"){$newmac=Generate-MacAddress}
            try {Set-DhcpServerv4Reservation -ComputerName $DHCPServer -ea stop -IPAddress $res.IPAddress -ClientID $newmac} catch {show-error $Error[0]}
            try {Edit-FilterLists -ea stop -list allow -Action Remove -mac $res.ClientID -HostName $res.name} catch {show-error $Error[0]}
            try {Edit-FilterLists -ea stop -list allow -Action add -mac $NewMac -HostName $res.name} catch {show-error $Error[0]}
            }
        2 {Set-DhcpServerv4Reservation -ComputerName $DHCPServer -IPAddress $res.IPAddress -Name $(read-host "Enter new host name")}
        3 {Set-DhcpServerv4Reservation -ComputerName $DHCPServer -IPAddress $res.IPAddress -Description $(Get-Group)}
        q {Show-Information}
        }

    $new=Get-DhcpServerv4Reservation -ComputerName $DHCPServer -IPAddress $res.IPAddress
    $res
    $new
    pause
    Replicate-Reservation
    Return $new | ft -AutoSize
    }

Function Export-Reservation()
    {
    Archive-Lists $FileLocation $FileLocation

    $Groups=Get-Content $GroupLocation\groups.txt

    foreach ($Group in $Groups)
        {
        $res=Get-DhcpServerv4Scope -ComputerName $DHCPServer -ea SilentlyContinue | % {Get-DhcpServerv4Reservation -ComputerName $DHCPServer -ScopeId $_.scopeid -ErrorAction SilentlyContinue} | ? {$_.description -eq $Group}
        if ($res)
            {
            $Res | % {$($_.IPAddress[0].ToString())+" "+$_.Name} | Out-File "$FileLocation\$group.txt"
            }
        }
    Return Get-ChildItem $FileLocation | ft LastWriteTime,Name -AutoSize 
    }

Function Find-Reservation()
    {
    $data=Read-Host "`nEnter reservation information (enter 'q' to quit)"
    
    if ($data -eq "q"){Show-Information}
    
    $res=Get-DhcpServerv4Scope -ComputerName $DHCPServer -ea SilentlyContinue | % {Get-DhcpServerv4Reservation -ComputerName $DHCPServer -ScopeId $_.scopeid -ErrorAction SilentlyContinue} | `
        ? {($_.name -eq $data) -or ($_.ipaddress -eq $data) -or ($_.clientid -eq $data)  -or ($_.name -eq $data)  -or ($_.description -eq $data)}
    
    Return $res | ft -AutoSize
    }

Function Clean-Filters()
    {
    foreach ($reservation in $reservations)
        {
        if (-not(Get-DhcpServerv4Filter -ComputerName $DHCPServer -List Allow | ? {$_.MacAddress -eq $reservation.ClientID}))
            {
            Add-DhcpServerv4Filter -ComputerName $DHCPServer -List Allow -MacAddress $reservation.ClientID -Description $Reservation.Name -PassThru
            }
        }

    foreach ($filter in $filters)
        {
        if ($reservations.clientID -notcontains $filter.MacAddress)
            {
            Remove-DhcpServerv4Filter -ComputerName $DHCPServer -MacAddress $filter.MacAddress -PassThru
            }
        }
    }

Show-Information
