<#       
    .SYNOPSIS
    Checks Microsoft Windows Cluster Status

    .DESCRIPTION
    Using WMI to check MS Cluster Resources, Disks, Nodes and Interfaces
    
    Copy this script to the PRTG probe EXEXML scripts folder (${env:ProgramFiles(x86)}\PRTG Network Monitor\Custom Sensors\EXEXML)
    and create a "EXE/Script Advanced" sensor. Choose this script from the dropdown and set at least:
    
    + Parameters: -Cluster Fileserver1
    + Security Context: Use Windows credentials of parent device

    .PARAMETER Cluster
    Cluster FQDN or Name

    .EXAMPLE
    Sample call from PRTG EXE/Script Advanced
    PRTG-MSCluster-Status.ps1 -Cluster %host

    Author:  Jannos-443
    https://github.com/Jannos-443/PRTG-MSCluster-Status

    https://docs.microsoft.com/en-us/previous-versions/windows/desktop/cluswmi/mscluster-resource
    https://docs.microsoft.com/en-us/previous-versions/windows/desktop/cluswmi/mscluster-clusterdiskpartition
    https://docs.microsoft.com/de-ch/previous-versions/windows/desktop/cluswmi/mscluster-networkinterface
    https://docs.microsoft.com/en-us/previous-versions/windows/desktop/cluswmi/mscluster-node
#>
param(
    [string]$Cluster = $null
)

#catch all unhadled errors
trap{
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>$($_.ToString() - $($_.ScriptStackTrace))</text>"
    Write-Output "</prtg>"
    Exit
}

#Cluster specified?
if(($Cluster -eq $null) -or ($Cluster -eq ""))
    {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>No Cluster specified</text>"
    Write-Output "</prtg>"
    Exit
    }


#Get Resources, Disks, Network Interfaces and Nodes
Try{
    $Resources = Get-CimInstance -Namespace "root\MSCluster" -ClassName "MSCluster_Resource" -ComputerName $Cluster -ErrorAction Stop
    $disks = Get-CimInstance -Namespace "root\MSCluster" -ClassName "MSCluster_DiskPartition" -ComputerName $Cluster -ErrorAction Stop
    $Interfaces = Get-CimInstance -Namespace "root\MSCluster" -ClassName "MSCluster_NetworkInterface" -ComputerName $Cluster -ErrorAction Stop
    $Nodes = Get-CimInstance -Namespace "root\MSCluster" -ClassName "MSCluster_Node" -ComputerName $Cluster -ErrorAction Stop
    }

catch{
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>Cluster $($Cluster) not found or access denied</text>"
    Write-Output "</prtg>"
    Exit
    }

$ActiveNodesTxt = "ActiveNodes: "
$ActiveNodes = ($Nodes | where {$_.state -eq 0}).Count

#Write Output
$xmlOutput = '<prtg>'

#Active Nodes Count
$xmlOutput = $xmlOutput + "<result>
        <channel>Nodes Active</channel>
        <value>$ActiveNodes</value>
        <unit>Count</unit>
        <limitmode>1</limitmode>
        <LimitMinError>1</LimitMinError>
        </result>"

#Nodes
foreach ($Node in $Nodes)
    {
    if($Node.state -eq "0")
        {
        $ActiveNodesTxt += "$($Node.name), "
        }
    $xmlOutput = $xmlOutput + "<result>
    <channel>Node $($Node.Name)</channel>
    <value>$($Node.State)</value>
    <ValueLookup>prtg.mscluster.nodes</ValueLookup>
    </result>"
    }


# Output Active Nodes
if($ActiveNodes -gt 0)
    {
    $xmlOutput = $xmlOutput + "<text>$($ActiveNodesTxt)</text>"
    }

# Output NO Active Nodes
else
    {
    $xmlOutput = $xmlOutput + "<text>No Active Nodes!</text>"
    }

#Recources
foreach ($Resource in $Resources)
    {
    $xmlOutput = $xmlOutput + "<result>
        <channel>Res $($Resource.Name)</channel>
        <value>$($Resource.State)</value>
        <ValueLookup>prtg.mscluster.resources</ValueLookup>
        </result>"
    }

#Disks
foreach ($disk in $disks)
    {
    $usedspace = [math]::Round((100-($disk.FreeSpace/$disk.TotalSize*100)),0)
    $name = "$($disk.Path) $($disk.VolumeLabel)"

    $xmlOutput = $xmlOutput + "<result>
        <channel>Disk $($name)</channel>
        <value>$($usedspace)</value>
        <unit>Percent</unit>
        <limitmode>1</limitmode>
        <LimitMaxError>95</LimitMaxError>
        <LimitMaxWarning>90</LimitMaxWarning>
        </result>"
    }


#Network Interfaces
foreach ($Interface in $Interfaces)
    {
    $xmlOutput = $xmlOutput + "<result>
        <channel>Net $($Interface.Name)</channel>
        <value>$($Interface.State)</value>
        <ValueLookup>prtg.mscluster.networkinterfaces</ValueLookup>
        </result>"
    }


$xmlOutput = $xmlOutput + "</prtg>"

$xmlOutput