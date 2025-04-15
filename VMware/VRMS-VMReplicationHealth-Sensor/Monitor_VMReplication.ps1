<#
.SYNOPSIS
    Monitor Replication Health Of VMs Configured On VMware Live Recovery (vSphere Replication)
 
.DESCRIPTION
    This PowerShell script is designed as a custom PRTG sensor for monitoring the replication health of VMs 
    configured on a vSphere replication appliance. It connects to the primary vSphere replication server, 
    retrieves replication data, and returns structured results for PRTG to process.

.NOTES
    Developed by: Akbar Raen
    Version: 1.0
    Date: April 15, 2025
    Dependencies:
        - PRTG Network Monitor
        - vSphere Replication PowerShell Module
        - PowerShell 5.1 or later
    License: MIT License   
#>

param (
    # Computer to connect to. Normally you don't need to specify this.
    [String]$ComputerName = $ENV:prtg_host,
    [double]$critThreshold = 0.4,
    [double]$warnThreshold = 0.4,
    # Manually specify credentials if needed.
    [Parameter(ParameterSetName = "Credential")][PSCredential]$Credential
)

# If there is a problem, output the error to PRTG directly.
$ErrorActionPreference = 'Stop'
trap { Stop-PRTGScript $PSItem }

# Drop process priority to avoid competing with other services.
(Get-Process -Id $pid).PriorityClass = 'BelowNormal'

# Obtain credentials from PRTG environment variables if available.
if ($ENV:prtg_windowspassword) {
    $User     = $ENV:prtg_windowsuser
    $Password = ConvertTo-SecureString $ENV:prtg_windowspassword -AsPlainText -Force
}

if ($User -and $Password) {
    $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $User, $Password
}

# Connect to the vSphere Replication Server.
$conn = Connect-VrServer -Server $ComputerName -Credential $Credential

# Get the pairing ID matching the connected vCenter.
$PairingID = ((Invoke-VrGetVrPairings).List |
              Where-Object { $_.LocalVcServer.Name -eq "$($conn.ConnectedPairings.Keys)" }).PairingId.GUID

# Get the vCenter GUID.
$VCGuid = (Invoke-VrGetVrInfo).VCGuid

# Get all configured replications, including extended info, and filter out the excluded VM ("pwdashc001").
$VMsReplStatus = foreach ($pairID in $PairingID) {
    (Invoke-VrGetAllReplications -pairingId $pairID -SourceVcGuid $VCGuid -ExtendedInfo $true).List |
        Select-Object Name,
                      @{Name="status"; Expression = { $_.status.status }},
                      @{Name="RpoViolation"; Expression = { $_.status.rpoviolation }},
                      RPO
}

# Define valid replication statuses.
$validStatuses = @("OK", "SYNC",)

# Determine the VMs with non-compliant replication status.
$failingVMs = $VMsReplStatus |
              Where-Object { $validStatuses -notcontains $_.status } |
              Select-Object -ExpandProperty Name

# Build the sensor message.
if ($failingVMs.Count -eq 0) {
    $sensorMessage = "All VMs replication are healthy"
} else {
    $sensorMessage = "Replication Status is critical for the VMs: " + ($failingVMs -join ", ")
}

# Build the PRTG sensor result set.
$sensorResult = New-PRTGResult

# Channel: Count of failing replications.
$sensorResult += @{
    Channel       = "Replication"
    Value         = $failingVMs.Count
    Unit          = "Count"
    LimitMode     = "1"
    LimitMaxError = $critThreshold
}

# Channel: Total number of replications monitored.
$totalReplications = $VMsReplStatus.Count
$sensorResult += @{
    Channel   = "Total Replication"
    Value     = $totalReplications
    Unit      = "Count"
    LimitMode = "0"
}

# Add the custom message to the sensor result.
Set-PRTGResultMessage -PRTGResultSet $sensorResult -Message $sensorMessage

# Set the output encoding and output the result.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[string]$sensorResult

# Disconnect the VRM session.
Disconnect-VrServer *
