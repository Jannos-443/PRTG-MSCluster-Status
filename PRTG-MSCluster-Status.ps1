<#       
    .SYNOPSIS
    Checks Microsoft Windows Cluster Status

    .DESCRIPTION
    Using WMI to check MS Cluster Resources, Disks, Nodes and Interfaces
    
    Copy this script to the PRTG probe EXEXML scripts folder (${env:ProgramFiles(x86)}\PRTG Network Monitor\Custom Sensors\EXEXML)
    and create a "EXE/Script Advanced" sensor. Choose this script from the dropdown and set at least:
    
    + Parameters: -Cluster Fileserver1
    + Security Context: Use Windows credentials of parent device

    Copy Lookup Files to (${env:ProgramFiles(x86)}\PRTG Network Monitor\lookups\custom) 
    - prtg.mscluster.networkinterfaces.ovl
    - prtg.mscluster.nodes.ovl
    - prtg.mscluster.resources.ovl


    .PARAMETER Cluster
    Cluster FQDN or Name

    .PARAMETER selChann
    Use to include/exclude for large Clusters

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
    [string]$Cluster = $null,
    [string]$selChann = "NRID" # Inital channel selection
)

$includeNodes = $selChann.Contains("N")
$includeResources = $selChann.Contains("R")
$includeInterfaces = $selChann.Contains("I")
$includeDisks = $selChann.Contains("D")

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
    if($includeNodes)
        {
        $Nodes = Get-CimInstance -Namespace "root\MSCluster" -ClassName "MSCluster_Node" -ComputerName $Cluster -ErrorAction Stop
        }
    
    if($includeResources)
        {
        $Resources = Get-CimInstance -Namespace "root\MSCluster" -ClassName "MSCluster_Resource" -ComputerName $Cluster -ErrorAction Stop
        }

    if($includeInterfaces)
        {
        $Interfaces = Get-CimInstance -Namespace "root\MSCluster" -ClassName "MSCluster_NetworkInterface" -ComputerName $Cluster -ErrorAction Stop
        
        }

    if($includeDisks)
        {
        $disks = Get-CimInstance -Namespace "root\MSCluster" -ClassName "MSCluster_DiskPartition" -ComputerName $Cluster -ErrorAction Stop
        }
      
    }

catch{
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>Cluster $($Cluster) not found or access denied</text>"
    Write-Output "</prtg>"
    Exit
    }



#Write Output
$xmlOutput = '<prtg>'

#Node Output:
if($includeNodes)
    {

    #Active Nodes Count 
    #Runs twice because we want "ActiveNodes" as First Channel
    $ActiveNodesTxt = "ActiveNodes: "
    $ActiveNodes = 0
    foreach ($Node in $Nodes)
        {
        if($Node.state -eq "0")
            {
            $ActiveNodes += 1
            $ActiveNodesTxt += "$($Node.name), "
            }
        }

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

    }

#Recources
if($includeResources)
    {
    foreach ($Resource in $Resources)
        {
        $xmlOutput = $xmlOutput + "<result>
            <channel>Res $($Resource.Name)</channel>
            <value>$($Resource.State)</value>
            <ValueLookup>prtg.mscluster.resources</ValueLookup>
            </result>"
        }

    }


#Disks
if($includeDisks)
    {
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

    }


#Network Interfaces
if($includeInterfaces)
    {
    foreach ($Interface in $Interfaces)
        {
        $xmlOutput = $xmlOutput + "<result>
            <channel>Net $($Interface.Name)</channel>
            <value>$($Interface.State)</value>
            <ValueLookup>prtg.mscluster.networkinterfaces</ValueLookup>
            </result>"
        }
    }


$xmlOutput = $xmlOutput + "</prtg>"

Write-Output $xmlOutput