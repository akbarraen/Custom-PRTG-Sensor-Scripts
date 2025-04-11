<#
.SYNOPSIS
    PRTG Custom Sensor for monitoring Nutanix Cluster Alerts and derived Cluster Health.

.DESCRIPTION
    This script retrieves unresolved alerts from a Nutanix Cluster using Nutanix PowerShell cmdlets.
    It then derives an overall cluster health score based on the presence of critical or warning alerts:

      - "Critical" if any critical alerts are present.
      - "Warning" if there are no critical alerts, but one or more warnings.
      - "Good" if there are no unresolved alerts.
      
    The sensor output channels include:
      - Critical Alerts
      - Warning Alerts
      - Critical Alerts Acknowledged
      - Warning Alerts Acknowledged
      - Total Alerts
      - Acknowledged Alerts
      - Derived Cluster Health Score (0 = Good, 1 = Warning, 2 = Critical, -1 = Unknown)

.NOTES
    Developed by: **********[Akbar Raen]**********
    File Name: PRTG_NutanixAlertsAndHealthSensor.ps1
    Dependencies: Nutanix PowerShell modules must be installed at the specified path.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$ComputerName = $ENV:prtg_host,

    [Parameter(Mandatory = $false)]
    [double]$CritThreshold = 0.4,

    [Parameter(Mandatory = $false)]
    [double]$WarnThreshold = 0.4,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential
)

# Configure error handling
$ErrorActionPreference = 'Stop'
trap { 
    if ($sensorSession) { 
        Disconnect-NTNXCluster -Servers $ComputerName 
    }
    Stop-PRTGScript $_ 
}

# Lower process priority to avoid resource contention
(Get-Process -Id $PID).PriorityClass = 'BelowNormal'

# Retrieve credentials from PRTG environment variables if not provided
if (-not $Credential -and $ENV:prtg_windowspassword) {
    $User = if ($ENV:prtg_windowsdomain) {
        "$($ENV:prtg_windowsdomain)\$($ENV:prtg_windowsuser)"
    } else {
        $ENV:prtg_windowsuser
    }
    $Password = ConvertTo-SecureString $ENV:prtg_windowspassword -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $User, $Password
}

# Import Nutanix PowerShell cmdlets (adjust the path as necessary)
& 'C:\Program Files (x86)\Nutanix Inc\NutanixCmdlets\powershell\import_modules\ImportModules.PS1'

# Connect to the Nutanix Cluster
$sensorSession = Connect-NTNXCluster -Server $ComputerName -UserName $Credential.UserName -Password $Credential.Password -AcceptInvalidSSLCerts
if (-not $sensorSession) {
    throw "Failed to connect to $ComputerName."
}

try {
    # Retrieve unresolved alerts from Nutanix Cluster
    $alerts = Get-NTNXAlert | Where-Object { $_.Resolved -eq $false }
    $alertSummary = @{
        Critical = @{
            Count    = 0
            AckCount = 0
            Messages = @()
        }
        Warning = @{
            Count    = 0
            AckCount = 0
            Messages = @()
        }
    }

    foreach ($alert in $alerts) {
        switch ($alert.Severity) {
            'kCritical' {
                $alertSummary.Critical.Count++
                $alertSummary.Critical.Messages += $alert.Message
                if ($alert.Acknowledged) { $alertSummary.Critical.AckCount++ }
            }
            'kWarning' {
                $alertSummary.Warning.Count++
                $alertSummary.Warning.Messages += $alert.Message
                if ($alert.Acknowledged) { $alertSummary.Warning.AckCount++ }
            }
        }
    }

    $sensorMessageAlerts = if ($alerts.Count -gt 0) {
        $criticalPart = if ($alertSummary.Critical.Count -gt 0) {
            "$($alertSummary.Critical.Count) Critical Alerts: $($alertSummary.Critical.Messages -join ', ')"
        }
        $warningPart = if ($alertSummary.Warning.Count -gt 0) {
            "$($alertSummary.Warning.Count) Warning Alerts: $($alertSummary.Warning.Messages -join ', ')"
        }
        $criticalPart, $warningPart -join "; "
    } else {
        "No Alerts in Nutanix Cluster"
    }

    # Retrieve cluster info for completeness (the returned object does not include a 'Health' property)
    $clusterInfo = Get-NTNXCluster
    if (-not $clusterInfo) {
        Write-Warning "Unable to retrieve cluster details, defaulting health to Unknown."
        $clusterHealthText = "Unknown"
    }
    else {
        # Derive overall cluster health based on alert counts
        if ($alertSummary.Critical.Count -gt 0) {
            $clusterHealthText = "Critical"
        }
        elseif ($alertSummary.Warning.Count -gt 0) {
            $clusterHealthText = "Warning"
        }
        else {
            $clusterHealthText = "Good"
        }
    }
    
    switch ($clusterHealthText.ToLower()) {
        'good'     { $clusterHealthValue = 0 }
        'warning'  { $clusterHealthValue = 1 }
        'critical' { $clusterHealthValue = 2 }
        default    { $clusterHealthValue = -1 }
    }

    # Build sensor result set for PRTG
    $sensorResult = New-PRTGResult
    $sensorResult += @{
        Channel       = "Critical Alerts"
        Value         = $alertSummary.Critical.Count
        Unit          = "Count"
        LimitMode     = "1"
        LimitMaxError = $CritThreshold
    }
    $sensorResult += @{
        Channel         = "Warning Alerts"
        Value           = $alertSummary.Warning.Count
        Unit            = "Count"
        LimitMode       = "1"
        LimitMaxWarning = $WarnThreshold
    }
    $sensorResult += @{
        Channel   = "Critical Alerts Acknowledged"
        Value     = $alertSummary.Critical.AckCount
        Unit      = "Count"
        LimitMode = "0"
    }
    $sensorResult += @{
        Channel   = "Warning Alerts Acknowledged"
        Value     = $alertSummary.Warning.AckCount
        Unit      = "Count"
        LimitMode = "0"
    }
    $sensorResult += @{
        Channel   = "Total Alerts"
        Value     = $alerts.Count
        Unit      = "Count"
        LimitMode = "0"
    }
    $sensorResult += @{
        Channel   = "Acknowledged Alerts"
        Value     = ($alertSummary.Critical.AckCount + $alertSummary.Warning.AckCount)
        Unit      = "Count"
        LimitMode = "0"
    }
    $sensorResult += @{
        Channel         = "Cluster Health Score"
        Value           = $clusterHealthValue
        Unit            = "Count"
        LimitMode       = "1"
        LimitMaxWarning = 0.5
        LimitMaxError   = 1.5
    }

    $sensorMessage = "$sensorMessageAlerts; Derived Cluster Health: $clusterHealthText"

    Set-PRTGResultMessage -PRTGResultSet $sensorResult -Message $sensorMessage

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [string]$sensorResult

} finally {
    # Ensure the Nutanix session is closed even if an error occurs
    Disconnect-NTNXCluster -Servers $ComputerName
}
