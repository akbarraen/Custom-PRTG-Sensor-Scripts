<#
.SYNOPSIS
  Retrieves open alarms from NSX-T using curl and outputs them in a PRTG sensor format.

.DESCRIPTION
  This script connects to an NSX Manager to retrieve alarms with a status of "OPEN" via its API.
  It categorizes the alarms as follows:
   - Red Alarms: Severities "HIGH" or "CRITICAL"
   - Yellow Alarms: Severities "MEDIUM" or "LOW"
  The script then outputs the alarm counts and details in a format that PRTG can process.

.PARAMETER ComputerName
  The hostname or IP of the NSX Manager. Defaults to the environment variable $prtg_host.

.PARAMETER critThreshold
  The error threshold for critical alarms. Default value is 0.4.

.PARAMETER warnThreshold
  The warning threshold for alarms. Default value is 0.4.

.PARAMETER Credential
  (Optional) A PSCredential object for NSX Manager authentication.
#>

param (
    [String]$ComputerName = $ENV:prtg_host,
    [double]$critThreshold = 0.4,
    [double]$warnThreshold = 0.4,
    [Parameter(ParameterSetName = "Credential")]
    [PSCredential]$Credential
)

# Output any errors directly to PRTG and stop on exceptions.
$ErrorActionPreference = 'Stop'
trap { Stop-PRTGScript $_ }

# Lower the process priority to avoid competing with other services.
(Get-Process -Id $pid).PriorityClass = 'BelowNormal'

############################
# Credential Handling
############################
if ($Credential) {
    $User = $Credential.UserName
    $Password = $Credential.GetNetworkCredential().Password
} elseif ($ENV:prtg_windowspassword) {
    $User = $ENV:prtg_windowsuser
    $Password = $ENV:prtg_windowspassword
} else {
    Write-Error "No credentials provided. Please supply a PSCredential or set the prtg_windowspassword environment variable."
    exit 1
}

############################
# Connect to NSX API with curl
############################
$nsxManager = "https://$ComputerName"
$uri = "$nsxManager/api/v1/alarms?status=OPEN"

# Specify the curl executable path.
$curlPath = "C:\Program Files\curl\bin\curl.exe"

# Execute curl to retrieve alarm data. Using -k to skip certificate validation, -s for silent output, and -G for GET.
$response = & $curlPath -G $uri -k -s -u "$User`:$Password"

# Convert the JSON response to a PowerShell object.
$rawAlarms = $response | ConvertFrom-Json

############################
# Process Alarms
############################
$redAlarms    = 0
$redArr       = @()
$yellowAlarms = 0
$yellowArr    = @()

if ($rawAlarms.result_count -gt 0) {
    $nxAlarms = $rawAlarms.results | Select-Object Id, summary, description, node_display_name, status, severity

    foreach ($entry in $nxAlarms) {
        $severity = $entry.severity.ToUpper()
        $alarmText = "$($entry.node_display_name) - $($entry.description)"
        switch ($severity) {
            'HIGH'      { $redAlarms++; $redArr += $alarmText }
            'CRITICAL'  { $redAlarms++; $redArr += $alarmText }
            'MEDIUM'    { $yellowAlarms++; $yellowArr += $alarmText }
            'LOW'       { $yellowAlarms++; $yellowArr += $alarmText }
        }
    }
}

# Construct the sensor message based on discovered alarms.
if ($redAlarms -eq 0 -and $yellowAlarms -eq 0) {
    $sensorMessage = "No Alarms in NSX Manager"
} else {
    $messageParts = @()
    if ($redAlarms -gt 0) {
        $messageParts += "$redAlarms Red Alarm(s): $([string]::Join(', ', $redArr))"
    }
    if ($yellowAlarms -gt 0) {
        $messageParts += "$yellowAlarms Yellow Alarm(s): $([string]::Join(', ', $yellowArr))"
    }
    $sensorMessage = $messageParts -join "; "
}

############################
# Build PRTG Sensor Output
############################
$sensorResult = New-PRTGResult

$sensorResult += @{
    Channel       = "Red Alarms"
    Value         = $redAlarms
    Unit          = "Count"
    LimitMode     = "1"
    LimitMaxError = $critThreshold
}

$sensorResult += @{
    Channel         = "Yellow Alarms"
    Value           = $yellowAlarms
    Unit            = "Count"
    LimitMode       = "1"
    LimitMaxWarning = $warnThreshold
}

$sensorResult += @{
    Channel   = "Total Alarms"
    Value     = $rawAlarms.result_count
    Unit      = "Count"
    LimitMode = "0"
}

Set-PRTGResultMessage -PRTGResultSet $sensorResult -Message $sensorMessage

# Ensure UTF-8 encoding for the output.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[string]$sensorResult
