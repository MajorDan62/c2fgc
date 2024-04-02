######################################################################
# C2FFC V1.0.240314  [C]isco [2] [F]ortiGate [F]irewall [C]onvertor  #
# Dated 14/03/2024                                                   #
######################################################################
function formattime{
        param ($delta)
        $timedelta  =  "$($delta.Hours)h "
        $timedelta  +=  "$($delta.Minutes)m "
        $timedelta  +=  "$($delta.Seconds)s "
        $timedelta  +=  "$($delta.Milliseconds)ms"
        return   $timedelta
}

function Convert-SubnetMaskToCIDR {
    param ([string]$subnetMask)
    $octets = $subnetMask.Split('.')
    $cidrPrefixLength = 0
    foreach ($octet in $octets) {
        $binaryOctet = [Convert]::ToString([int]$octet, 2)
        $cidrPrefixLength += $binaryOctet.ToCharArray() | Where-Object { $_ -eq '1' } | Measure-Object | Select-Object -ExpandProperty Count
    }
    return "$cidrPrefixLength"
}

function ScreenAlignment        {param ( [int]$x,[int]$y);$Host.UI.RawUI.CursorPosition = New-Object Management.Automation.Host.Coordinates $x, $y}
function ProcessHostname        {return  ((gc -path $SelectedFile  | Select-String -Pattern '^hostname.*' ) -Split(" "))[1]}
function ProcessInterfacename   {return  ((gc -path "$SelectedFile" | Select-String -Pattern '^Interface.*'))}
function getinterfacedetails
{
    #getinterfacedetails
    param ( [string] $startPattern)
    $endPattern = "!"
    $startIndex = $data.IndexOf($startPattern)
    $interfaceinfo=$Null
    do{$interfaceinfo += $data[$startIndex] + [char]10;$startindex++}until ($data[$startIndex] -eq $endPattern)
    return $interfaceinfo
}
######################################################################
function getinterfaceparameters
{
    param ( [string] $datastring,[string] $startPattern)  
    $startPattern   +=  " (.*)"   
    $results        =   $datastring | Select-String -Pattern $startPattern  | ForEach-Object { $_.Matches.Groups[1].Value }
    return $results
}
######################################################################
function getinterfacestatus
{
    param ( [string] $datastring,[string] $startPattern)  
    $results        =   $datastring | Select-String -Pattern $startPattern 
    if ($results){$results = "Down"}
    return $results
}
######################################################################
function getinfo
{
    param ( [string] $data,[string] $startPattern)
    $results        =    ($datastring | Select-String -Pattern $startpattern) | Select-Object   -First 1
    return $results
}
######################################################################
function gethosts
{
    param ( [string] $datastring,[string] $startPattern)  
    $results        =    ($datastring | Select-String -Pattern $startpattern)
    return $results
}
#######################################################################
functIon findDHCPserverrelay
{
    param ( [string]  $regexPattern)  
    $dhcpserver     =   $data | Select-String -pattern $regexPattern
    $results        =   $Null
    if (($dhcpserver.count) -gt "0")
    {
        $regexPattern   = '\b(?:\d{1,3}\.){3}\d{1,3}\b'
        $matches        = [regex]::Matches($dhcpserver, $regexPattern)
        $results        = "      set dhcp-relay-service enable
        set dhcp-relay-ip " + ($matches.value  -join '" "' | ForEach-Object { '"' + $_ + '"' })
    }
    return $results
}
######################################################################
function findNATentries
{ 
    $regexPattern   =   "nat.*static"
    $lines          =   ($data | Select-String -Pattern $regexPattern) -split '\r?\n'
    [int]$c         =   0
    $vip            =   $null
    $_vip           =   $null
    $extintf        =   $null
    $_extintf       =   $null
    $__extintf      =   $null
    #Iterate over each line and extract the IP address
    for ($c=0;$c -lt $lines.count;$c++) {$vip +=  [string]"vip-"+(($lines[$c] -split '\s+')[4]+",")};$_vip= $vip -split ","
    for ($c=0;$c -lt $lines.count;$c++){ $extintf += ((((($lines[$c]-split ' ')[2])  -split ',')[1])+",")};$_extintf  = $extintf -replace "vlan",$vdom -replace "\)","";$__extintf = $_extintf -split ","

    # Get the previous line for each match and extract the IP address
    $matches = $data | Select-String -Pattern "nat.*static"
    $ipAddress      =   $null
    foreach ($match in $matches) {$index = $match.LineNumber - 2
        if ($index -ge 0) {
            $previousLine = $data -split '\r?\n' | Select-Object -Index $index
            $ipAddress += $previousLine -replace '.*(\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b).*', '$1'
            $ipAddress += ","
        } 
    }
    $_ipAddress = $ipAddress -split ","
    foreach ($match in $matches){
        $c++
        $__vip= $_vip[$c] -replace ('vip-', "")
        $template = "   edit $_vip[$c]
                            set ext ip $__extintf[$c]
                            set mappedip $_ipadress[$c]
                            set extinf $__vip"
    }
}
###############################################################################
function getHostObjects
{
    $cr=[char]10
    $regexPattern = 'network-object.* host'

    #first pass of getting the data
    $matches                = ($data | Select-String -Pattern $regexPattern) | Get-Unique 
    $hostIPRegex            = "host (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"  
    $HostObjectName,$HostIP =   $Null
    foreach ($match in $matches){
        $c++
        $HostIP         =   [regex]::Match($match, $hostIPRegex).Groups[1].Value
        $HostObjectName +=   "edit " + $dq +"obj-" + $HostIP + $dq + $cr
    }  
    $hosts                  =   ($HostObjectName  -split "`n") | Sort-Object -Unique 

    #second pass of getting data 
    $regexPattern           =   'access-list.* host (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'
    $ipRegex                = '(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'
    $HostObjectName,$src    =   $Null
    $matches                =   ($data | Select-String -Pattern $regexPattern) | Get-Unique 
    foreach ($match in $matches){
        $sourceIP          =   [regex]::Matches($match, $ipRegex) | ForEach-Object { $_.Value }
        if ($sourceIP.Count -eq 2){$HostObjectName     +=   "edit " + $dq +"h-" +  $sourceIP[0] + $dq + $cr}
    }
    $src = ($HostObjectName  -split "`n") | Sort-Object -Unique 

    #third pass of getting data 
    $regexPattern           = 'access-list.*host (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'
    $ipRegex                = '(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'
    $HostObjectName,$dst     =   $Null
    $matches                = ($data | Select-String -Pattern $regexPattern) | Get-Unique 
    foreach ($match in $matches){
        $destinationIP           =   [regex]::Matches($match, $ipRegex) | ForEach-Object { $_.Value }
        if ($destinationIP.Count -eq 2){$HostObjectName     +=   "edit " + $dq +"h-" +  $destinationIP[1] + $dq + $cr}
    }
    $dst = ($HostObjectName  -split "`n") | Sort-Object -Unique 

    #cleanup the collected data
    $results    =  $hosts + $cr + $src + $cr + $dst 
    $results    = ($results -split "`n") | Sort-Object -Unique 
    $template   =   $null
#     $prefix     = "config vdom
#     edit "+$dq + $vdom + $dg + "
#     config firewall address
#     "  
#     $suffix     =   "end
# end"
    foreach ($result in $results)
    {
        $pattern = "\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"
        if ($result -match $pattern){$_ipAddress     = $matches[0]}
        if ($result){
        $template       += "  " + $result + "
        set " + $_ipAddress + " 255.255.255.255
    next
    "}
    }
    $template = $template
   return $template 
}
###############################################################################
function getnetworkobject
{
    # format network-object 31.221.110.80 255.255.255.248
    $lines          =   $data   |   Select-String -Pattern 'network-object.*\d+\.\d+\.\d+\.\d+ \d+\.\d+\.\d+\.\d+'
    $lines          =   $lines  |   Sort-Object -Unique
    $template       =   $Null
    for ($c=0;$c -lt ($lines.count);$c++){
        $networkobject  =   $lines[$c]
        $networkobject  =   $networkobject -split(" ")
        $subnetmask     =   Convert-SubnetMasktoCIDR -subnet $networkobject[3]
        $template       +=  "edit " + $dq + "n-" + $networkobject[2] + "_" + $subnetmask + $dq + "
            set " + $networkobject[2] + " " + $networkobject[3] + "
        next
"
    }   
return $template
}
###############################################################################
function getNetworkObjects
{
    #   access-list in-from-vni-live-v22 extended permit tcp 172.18.107.0 255.255.255.0 host 194.176.201.195 eq smtp
    #   access-list in-from-vni-live-v22 extended permit tcp 172.17.105.0 255.255.255.0 172.30.1.0 255.255.255.0 eq https
    $accessLists    = $data -split "`n" | Where-Object { $_ -match '^access-list' }
    $pattern = "\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b \b255\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"

    $_subnet=$NULL
    foreach ($line in $accessLists) {
        $match = [regex]::Matches($line, $pattern)
        if ($match.count -eq 2)
        {
            $subnet     = $match.Groups[0].Value.Split(" ")[0]
            $mask       = $match.Groups[0].Value.Split(" ")[1]
            $_subnet    += $subnet + " " + $mask + $cr
        }
        if  ($match.count -eq 1 )
        {
            $subnet     = $match.Groups[0].Value.Split(" ")[0]
            $mask       = $match.Groups[0].Value.Split(" ")[1]
            $_subnet    += $subnet + " " + $mask + $cr
        }
    }

    $lines          =   $data | Select-String -Pattern 'network-object.*\d+\.\d+\.\d+\.\d+ \d+\.\d+\.\d+\.\d+'
    $lines          =   $lines |   Sort-Object -Unique

    for ($c=0;$c -lt ($lines.count);$c++){
        $networkobject  =$lines[$c]
        $networkobject  = $networkobject -split(" ")
        $_subnet +=  $networkobject[2] + " " +  $networkobject[3] + $cr
    }   

    $__subnet   =   $_subnet -split $cr
    $___subnet  =  $__subnet | sort-Object -Unique
    $___subnet  =   $___subnet  | Where-Object { $_ -match '\S' }

    $networkobjects = $null
    for ($c=0;$c -le ($___subnet.count - 1);$c++) {
        $_data  =   $___subnet[$c] -split(" ")
        $cidr   =   Convert-SubnetMaskToCIDR -subnetmask $_data[1]
        $networkobjects += "    edit " + $dq +"n-" + $_data[0] + "_" + $cidr + $dq + "
        set subnet " + $___subnet[$c] + "
    next
"
    }
    return $networkobjects
}

##DEFAULTS####################################################
$_genesis               =   "$PWD\genesis"
$_revelation            =   "$PWD\revelation"
$CiscoTextFiles         =   Get-ChildItem -Path $_genesis -Filter *.txt
$NumberOfCiscoTextFiles =   $CiscoTextFiles.Count
$cr                     =   [char]10
$dq                     =   [char]34
$epoch_start            =   Get-date
$epoch_genesis          =   Get-date
$interfacedetails       =   @()
$interfacequeries       =   @("interface","vlan","nameif","security-level","ip address","shutdown")
$vdom                   =   "FW009_10"
$systeminterface        =   "X1-X2."
$_prefix                =   "config vdom
edit " + $dq + $vdom + $dq + $cr +
"config system interface"
$_suffix                =   "end
end
"
$systemsessionTTL       = [int]3600
cls
write-host -b yellow -f black "                                                       "
write-host -b yellow -f black "   C2FFC V1.0.240314                                   "
write-host -b yellow -f black "   [C]isco [2] [F]ortiGate [F]irewall [C]onvertor      "
write-host -b yellow -f black "                                                       "
write-host -b green -f black  " Cisco Configuration Files avialable in this directory "

ScreenAlignment -x 0 -y 6
for ($i = 0; $i -lt $NumberOfCiscoTextFiles; $i++) {Write-Host "$($i + 1). $($CiscoTextFiles[$i])"}
ScreenAlignment -x 0 -y ( $NumberOfCiscoTextFiles + 7)

$host.UI.RawUI.ForegroundColor = "Green"
$userChoice = Read-Host "Enter the number of your choice"
$host.UI.RawUI.ForegroundColor = "White"
if (($userChoice -ge 1) -and ($userChoice -le $NumberOfCiscoTextFiles))
        {write-Host "Policy Selected: $($CiscoTextFiles[($userChoice-1)])";$SelectedFile="$_genesis\$($CiscoTextFiles[($userChoice-1)])";$data = gc -path $SelectedFile} 
    else 
        {Write-Host "[$userChoice] Invalid choice. Please enter a valid number.";exit}
$epoch_start            =   Get-date

###############################################
#01-config-system-global#######################
###############################################
$hostname = ProcessHostname
$configsystemglobal="config global
    config system global
        set hostname "  + $dq + $hostname + $dq + "
        set vdom-mode multi-vdom
        set tcp-halfclose-timer 600
        set udp-idle-timer 120
    end
end"
$exportfile =   $_revelation + "\$hostname-01-config-system-global.txt"
$configsystemglobal | Out-File -FilePath $exportfile
$cursorPosition = $Host.UI.RawUI.CursorPosition
$_delta = (Get-date) - $epoch_start ;$epoch_start=(Get-date);$_delta = formattime $_delta
write-host -f green "$exportfile PROCESSED ($_delta)"
###############################################
#02-config-system-interface####################
###############################################
$interfaces = ProcessInterfacename
if ($interfaces){write-host -f green $interfaces.count"Interfaces Located"}else{write-host -f red "No Interfaces Located"}
$counter=0
do{
    $regexPattern       =   $Null
    $slod               =   getinterfacedetails $interfaces[$counter]
    $interfacedetails   +=  $slod
    $interface          =   getinterfaceparameters $slod "interface"
    $_interface         =   $interface -Split "/|\."
    $_interface         =   $($_interface[0])+"/"+$($_interface[1])
    $description        =   getinterfaceparameters $slod "description"
    $vlan               =   getinterfaceparameters $slod "vlan"
    $nameif             =   getinterfaceparameters $slod "nameif"
    $seuritylevel       =   getinterfaceparameters $slod "security-level"
    $ipaddress          =   getinterfaceparameters $slod "ip address"
    $interfaceStatus    =   getinterfacestatus $slod "shutdown"
    $edit               =   $systeminterface + $vlan  
    $_ipaddress         =   ($ipaddress -Split " ")[0]
    $_subnetmask        =   ($ipaddress -Split " ")[1]
    $counter++
    if ($nameif -and $vlan)
    {
        $dhcpentries    =   getinterfaceparameters $slod "dhcprelay server"
        $DHCPserver     =   findDHCPserverrelay "dhcprelay server.*$vlan"
        $template  +=   $cr + 
"    edit "+ $dq + $edit  + $dq + $cr +
"        set vdom " + $dq + $vdom + $dq + $cr + 
"        set alias " + $dq + $nameif + $dq + $cr +
"        set allowaccess ping https ssh snmp http telnet
        set mode static
        set ip  $_ipaddress $_subnetmask" + $cr
    if ($DHCPserver){$template +=    $DHCPserver + $cr}
        $template +=    "        set interface " + $dq + $_interface + $dq + $cr +
"        set vlanid $vlan
        set description "+$dq + $description + $dq + $cr 
if (!$interfaceStatus){$template +=  "        set status up" + $cr}else{$template +=  "         set status down" + $cr}
    $template += "  next"
        }
    }until ($counter -gt ($interfaces.count ))
$template = $_prefix + $template + $cr + $_suffix
$exportfile =   $_revelation + "\$hostname-02-config-system-interface.txt"
$template | Out-File -FilePath $exportfile
ScreenAlignment -x 0 -y ($cursorPosition.y + 1)
$_delta = (Get-date) - $epoch_start ;$epoch_start=(Get-date);$_delta = formattime $_delta
write-host -f green "$exportfile PROCESSED ($_delta)"

###############################################
#03-config-system-dns##########################
###############################################
$exportfile     =   $_revelation + "\$hostname-03-config-system-dns.txt"
$domainname     =   getinfo $data "domain-name"
$template       =   "config vdom
    edit "+ $dq + $vdom + $dq + "
    config system dns
        set domian " + $dq + $domainname + $dq + $cr + $_suffix
$template | Out-File -FilePath $exportfile
$_delta = (Get-date) - $epoch_start ;$epoch_start=(Get-date);$_delta = formattime $_delta
write-host -f green "$exportfile PROCESSED ($_delta)"

###############################################
#04-config-system-session-ttl##################
###############################################
$exportfile     =   $_revelation + "\$hostname-04-config-system-session-ttl.txt"
$domainname     =   getinfo $data "domain-name"
$template       =   "config vdom
    edit "+ $dq + $vdom + $dq + "
    config system session-ttl
    set default " + $systemsessionTTL + $cr + $_suffix
$template | Out-File -FilePath $exportfile
$_delta         =   (Get-date) - $epoch_start ;$epoch_start=(Get-date);$_delta = formattime $_delta
write-host -f green "$exportfile PROCESSED ($_delta)"

###############################################
#05-config-firewall-address####################
###############################################
$exportfile     =   $_revelation + "\$hostname-05-config-firewall-address.txt"
$template       =   getHostObjects
$template       +=  getNetworkobjects
$template       +=  getNetworkobject
$prefix         =   "config vdom
edit "+ $dq +  $vdom + $dq + "
config firewall address
"
$suffix         =   "end
end"
$template       =   $prefix + $template + $suffix
$template   | Out-File -FilePath $exportfile
$_delta         = (Get-date) - $epoch_start ;$epoch_start=(Get-date);$_delta = formattime $_delta
write-host -f green "$exportfile PROCESSED ($_delta)"

###############################################
#CLEAN UP ROUTINE##############################
###############################################
$_delta = (Get-date) - $epoch_genesis ;$epoch_start=(Get-date);$_delta = formattime $_delta
Write-host -f red "Script Ended [$_delta]"
