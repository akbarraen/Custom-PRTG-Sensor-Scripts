<#
.SYNOPSIS
    Checks SimpliVity Cluster Health, Storage Usage, and Arbiter Status.

.DESCRIPTION
    This script connects to a SimpliVity cluster to evaluate:
      • Overall space usage
      • OVC host status (cluster health)
      • Arbiter connectivity
      • Disk health across the cluster

    The results are returned to PRTG using the PRTGResultSet module.
#>
#requires -Module PRTGResultSet, HPESimpliVity

param (
    # Computer to connect to; usually provided by the PRTG environment
    [String]$ComputerName = $ENV:prtg_host,
    # Threshold for SimpliVity Space Usage (percent)
    [int]$critThreshold = 80,
    [int]$warnThreshold = ($critThreshold - 10),
    # Threshold for status channels (set low so that value '1' indicates an error condition)
    [decimal]$critThresholdHealth = 0.4,
    # Manually specify credentials if needed
    [Parameter(ParameterSetName = "Credential")][PSCredential]$Credential
)

# Stop PRTG immediately on error
$ErrorActionPreference = 'Stop'
trap { Stop-PRTGScript $_ }

# Lower process priority to avoid impacting other services
(Get-Process -Id $pid).PriorityClass = 'BelowNormal'

# Retrieve credentials from PRTG environment variables, if provided
if ($ENV:prtg_windowspassword -and $ENV:prtg_windowsuser) {
    $User = $ENV:prtg_windowsuser
    if ($ENV:prtg_windowsdomain) {
        $User = "$($ENV:prtg_windowsdomain)\$User"
    }
    $Password = ConvertTo-SecureString $ENV:prtg_windowspassword -AsPlainText -Force  
    $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $User, $Password
}

# Establish connection to the SimpliVity cluster (OVC)
$sensorOVCSession = Connect-Svt -OVC $ComputerName -Credential $Credential
if (-not $sensorOVCSession) { throw "Connection to $ComputerName failed for an unknown reason." }

# Retrieve the cluster statistics
$svtClusterStat = Get-SvtCluster

# --- Arbiter Status ---
if ($svtClusterStat.ArbiterConnected -eq "TRUE") {
    $svtArbStat    = 0
    $svtArbStatMess = "Arbiter Connected"
} else {
    $svtArbStat    = 1
    $svtArbStatMess = "Arbiter [$($svtClusterStat.ArbiterIP)] is not connected to the SimpliVity Cluster"
}

# --- SimpliVity Cluster (OVC) Health ---
$svtHostsStat = Get-SvtHost | Select-Object HostName, State, ManagementIP
$hostIssues = @()

foreach ($host in $svtHostsStat) {
    if ($host.State -ne "ALIVE") {
        $hostIssues += "ESXi: $($host.HostName) (OVC IP: $($host.ManagementIP)) is not alive."
    }
}

if ($hostIssues.Count -eq 0) {
    $svtClusterHealth     = 0
    $svtClusterHealthMess = "All OVCs are ALIVE"
} else {
    $svtClusterHealth     = 1
    $svtClusterHealthMess = $hostIssues -join " "
}

# --- Cluster Space Usage ---
$allocated = $svtClusterStat.AllocatedCapacityGB
$free      = $svtClusterStat.FreeSpaceGB

if ($allocated -and $allocated -ne 0) {
    [decimal]$svtCluSpUsage = [math]::round((($allocated - $free) / $allocated) * 100, 2)
} else {
    $svtCluSpUsage = 0
}
$svtCluSpUsageMess = "SimpliVity Space Usage is at $svtCluSpUsage%"

# --- Disks Health ---
$Disks = Get-SvtDisk
$diskIssues = @()

foreach ($disk in $Disks) {
    if ($disk.Health -ne "HEALTHY") {
        $diskIssues += "Disk SN: $($disk.SerialNumber) on Host: $($disk.HostName) is not healthy."
    }
}

if ($diskIssues.Count -eq 0) {
    $svtDisksHealth     = 0
    $svtDisksHealthMess = "All disks in the cluster are healthy"
} else {
    $svtDisksHealth     = 1
    $svtDisksHealthMess = $diskIssues -join " "
}

# --- Build the PRTG Sensor Result ---

$sensorResult = New-PRTGResult

# Channel: Space Usage
$sensorResult += @{
    Channel         = "SimpliVity Space Usage"
    Value           = $svtCluSpUsage
    Unit            = "Percent"
    LimitMode       = 1
    LimitMaxWarning = $warnThreshold
    LimitMaxError   = $critThreshold
}

# Channel: Cluster Health
$sensorResult += @{
    Channel         = "SimpliVity Cluster Health"
    Value           = $svtClusterHealth
    Unit            = "Count"
    LimitMode       = 1
    LimitMaxError   = $critThresholdHealth
}

# Channel: Arbiter Status
$sensorResult += @{
    Channel         = "Arbiter Status"
    Value           = $svtArbStat
    Unit            = "Count"
    LimitMode       = 1
    LimitMaxError   = $critThresholdHealth
}

# Channel: Disks Health
$sensorResult += @{
    Channel         = "SimpliVity Disks Health"
    Value           = $svtDisksHealth
    Unit            = "Count"
    LimitMode       = 1
    LimitMaxWarning = $warnThreshold
    LimitMaxError   = $critThreshold
}

# Combine all messages into one sensor message
$sensorMessage = "$svtCluSpUsageMess, $svtClusterHealthMess, $svtArbStatMess, $svtDisksHealthMess"

# Set the sensor message for PRTG
Set-PRTGResultMessage -PRTGResultSet $sensorResult -Message $sensorMessage

# Output the result
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[string]$sensorResult
