<#
.SYNOPSIS
    PRTG Custom Sensor for Monitoring Zerto Environment via Zerto API using Curl

.DESCRIPTION
    This sensor monitors multiple aspects of a Zerto replication environment:
    
    [ZVM Monitoring]
      • Alerts: Counts high-severity alerts and builds a detailed message.
      
    [VPG Monitoring]
      • VPG Status: Evaluates the health of Virtual Protection Groups.
      
    [VRA Monitoring]
      • Total VRAs, healthy/unhealthy counts, total memory, and total CPUs.
      • If any VRA (named via VraName) is not healthy, its name is reported.
      
    [License Monitoring]
      • Checks license details and usage.
      • Raises an alert if the total licensed VMs (MaxVms) is exceeded by the usage (TotalVmsCount).
      
    The sensor returns the following channels:
      • ZVM Alerts (Count)
      • VPG Status (1 = healthy, 0 = not healthy)
      • VRA Total, Healthy VRAs, Unhealthy VRAs, Total VRA Memory (GB), and Total VRA CPUs
      • Zerto License Status (1 = OK, 0 = alert), Max Licensed VMs, and Total VMs in Use
      
    A combined sensor message provides detailed context from all areas.
    
.NOTES
    Developed by: Akbar Raen
    Version: 1.0
    Date: April 18, 2025
#>

#requires -Module PRTGResultSet

param (
    # The computer name is typically provided by PRTG.
    [String]$ZVM_IP = $ENV:prtg_host,
    $critThreshold = 0.4,
    $warnThreshold = 0.4,
    # Optionally, specify a credential.
    [Parameter(ParameterSetName = "Credential")][PSCredential]$Credential,
    $ClientID     = $User,
    $ClientSecret = $Password
)

# Stop on error and trap any exception
$ErrorActionPreference = 'Stop'
trap { Stop-PRTGScript $_ }

# Lower the process priority to avoid impacting production services.
(Get-Process -Id $pid).PriorityClass = 'BelowNormal'

# Get credentials from PRTG environment if available.
if ($ENV:prtg_windowspassword) {
    $User = $ENV:prtg_windowsuser
    if ($ENV:prtg_windowsdomain) {
        $User = "$($ENV:prtg_windowsdomain)\$User"
    }
    $Password = $ENV:prtg_windowspassword
}

#-------------------------------
# Get API Token from the ZVMA server 
#-------------------------------
# Define ZVM details
    $ClientID     = $User
    $ClientSecret = $Password

$CurlCommand  = "curl.exe -s -k --location `"https://$ZVM_IP/auth/realms/zerto/protocol/openid-connect/token`" " + `
                "--header `"Content-Type: application/x-www-form-urlencoded`" " + `
                "--data-urlencode `"client_id=$ClientID`" " + `
                "--data-urlencode `"client_secret=$ClientSecret`" " + `
                "--data-urlencode `"grant_type=client_credentials`""
$TokenResponse = Invoke-Expression $CurlCommand
$SessionToken  = ($TokenResponse | ConvertFrom-Json).access_token

#============================================================================================================#
# ZVM ALERTS: Retrieve and process alerts from Zerto.
try {
    $CurlCommand = "curl.exe -s -k --location `"https://$ZVM_IP/v1/alerts`" " + `
                   "--header `"Authorization: Bearer $SessionToken`" " + `
                   "--header `"Accept: application/json`""
    $alerts = Invoke-Expression $CurlCommand | ConvertFrom-Json

    # Normalize to array
    $alerts = @($alerts)

    # Filter alerts by level.
    $errorAlerts   = $alerts | Where-Object { $_.Level -eq "Error" }
    $warningAlerts = $alerts | Where-Object { $_.Level -eq "Warning" }

    $errorMsgParts = @()
    $i = 1
    foreach ($alert in $errorAlerts) {
        $errorMsgParts += "$i Error: $($alert.Description)"
        $i++
    }
    $errMsg = if (($errorMsgParts|Measure-Object).Count -gt 0) { $errorMsgParts -join ", " } else { "" }

    $warningMsgParts = @()
    $j = 1
    foreach ($alert in $warningAlerts) {
        $warningMsgParts += "$j Warning: $($alert.Description)"
        $j++
    }
    $warnMsg = if (($warningMsgParts|Measure-Object).Count -gt 0) { $warningMsgParts -join ", " } else { "" }

    if ($errMsg -and $warnMsg) {
        $alertsMsg = "$errMsg and $warnMsg"
    }
    elseif ($errMsg) {
        $alertsMsg = $errMsg
    }
    elseif ($warnMsg) {
        $alertsMsg = $warnMsg
    }
    else {
        $alertsMsg = "There are no active alerts"
    }
    
    # Total alert count.
    $zvmAlertCount = ($errorAlerts|Measure-Object).Count + ($warningAlerts|Measure-Object).Count
}
catch {
    $alertsMsg     = "Error retrieving alert data: $_"
    $zvmAlertCount = 0
}

#============================================================================================================#
# VPG STATUS: Check Virtual Protection Groups health.
try {
    $CurlCommand = "curl.exe -s -k --location `"https://$ZVM_IP/v1/vpgs`" " + `
                   "--header `"Authorization: Bearer $SessionToken`" " + `
                   "--header `"Accept: application/json`""
    $vpgs = Invoke-Expression $CurlCommand | ConvertFrom-Json
    $vpgs = @($vpgs)

    # A healthy VPG is assumed to have Status equal to 1.
    $unhealthyVpgs = $vpgs | Where-Object { $_.StatusDescription -ne "MeetingSLA" }
    if (($unhealthyVpgs|Measure-Object).Count -gt 0) {
        $vpgNames = $unhealthyVpgs | ForEach-Object { $_.VpgName }
        $namesString = $vpgNames -join ", "
        $vpgMsg = if (($vpgNames|Measure-Object).Count -eq 1) {
            "$namesString is not healthy"
        }
        else {
            "$namesString are not healthy"
        }
        $vpgStatus = 0
    }
    else {
        $vpgMsg = "All VPGs are healthy"
        $vpgStatus = 1
    }
}
catch {
    $vpgMsg    = "Error retrieving VPG data: $_"
    $vpgStatus = 0
}

#============================================================================================================#
# VRA MONITORING: Check Virtual Replication Appliances.
try {
    $CurlCommand = "curl.exe -s -k --location `"https://$ZVM_IP/v1/vras`" " + `
                   "--header `"Authorization: Bearer $SessionToken`" " + `
                   "--header `"Accept: application/json`""
    $vras = Invoke-Expression $CurlCommand | ConvertFrom-Json
    $vras = @($vras)
    
    $vraTotal    = ($vras|Measure-Object).Count
    $vraHealthy  = 0
    $vraUnhealthy= 0
    $vraUnhealthyNames = @()
    $totalMemory = 0
    $totalCpus   = 0

    foreach ($vra in $vras) {
        $totalMemory += $vra.MemoryInGB
        $totalCpus   += $vra.NumOfCpus

        # Define a healthy VRA as one with Status==0 and VraAlerts.VraAlertsStatus==0.
        if (($vra.Status -eq 0) -and ($vra.VraAlerts.VraAlertsStatus -eq 0)) {
            $vraHealthy++
        }
        else {
            $vraUnhealthy++
            $vraUnhealthyNames += $vra.VraName
        }
    }
    
    $vraMsg = if ($vraUnhealthy -gt 0) {
        "Unhealthy VRA(s): " + ($vraUnhealthyNames -join ", ")
    }
    else {
        "All VRAs are healthy"
    }
}
catch {
    $vraMsg     = "Error retrieving VRA data: $_"
    $vraTotal    = 0
    $vraHealthy  = 0
    $vraUnhealthy= 0
    $totalMemory = 0
    $totalCpus   = 0
}

#============================================================================================================#
# LICENSE MONITORING: Query Zerto license details.
try {
    $CurlCommand = "curl.exe -s -k --location `"https://$ZVM_IP/v1/license`" " + `
                   "--header `"Authorization: Bearer $SessionToken`" " + `
                   "--header `"Accept: application/json`""
    $licenseResponse = Invoke-Expression $CurlCommand | ConvertFrom-Json
    
    $maxVms   = $licenseResponse.Details.MaxVms
    $totalVms = $licenseResponse.Usage.TotalVmsCount

    if ($totalVms -gt $maxVms) {
        $licenseStatus = 0  # Alert condition.
        $licenseMsg = "Zerto has license for $maxVms VMs, but usage is $totalVms VMs."
    }
    else {
        $licenseStatus = 1
        $licenseMsg = "License OK: Zerto license for $maxVms VMs, usage is $totalVms VMs."
    }
}
catch {
    $licenseMsg = "Error retrieving license data: $_"
    $licenseStatus = 0
    $maxVms   = 0
    $totalVms = 0
}

#============================================================================================================#
# Assemble the PRTG Sensor Result
$sensorResult = New-PRTGResult

# --- ZVM Monitoring ---
$sensorChannel = @{
    Channel   = "ZVM Alerts"
    Value     = $zvmAlertCount
    Unit      = "Count"
    LimitMode = 0
}
$sensorResult += $sensorChannel

# --- VPG Monitoring ---
$sensorChannel = @{
    Channel   = "VPG Status"
    Value     = $vpgStatus
    Unit      = "Status"
    LimitMode = 0
}
$sensorResult += $sensorChannel

# --- VRA Monitoring ---
$sensorChannel = @{
    Channel   = "VRA Total"
    Value     = $vraTotal
    Unit      = "Count"
    LimitMode = 0
}
$sensorResult += $sensorChannel

$sensorChannel = @{
    Channel   = "Healthy VRAs"
    Value     = $vraHealthy
    Unit      = "Count"
    LimitMode = 0
}
$sensorResult += $sensorChannel

$sensorChannel = @{
    Channel   = "Unhealthy VRAs"
    Value     = $vraUnhealthy
    Unit      = "Count"
    LimitMode = 0
}
$sensorResult += $sensorChannel

$sensorChannel = @{
    Channel   = "Total VRA Memory (GB)"
    Value     = $totalMemory
    Unit      = "GB"
    LimitMode = 0
}
$sensorResult += $sensorChannel

$sensorChannel = @{
    Channel   = "Total VRA CPUs"
    Value     = $totalCpus
    Unit      = "Count"
    LimitMode = 0
}
$sensorResult += $sensorChannel

# --- License Monitoring ---
$sensorChannel = @{
    Channel   = "Zerto License Status"
    Value     = $licenseStatus
    Unit      = ""
    LimitMode = 0
}
$sensorResult += $sensorChannel

$sensorChannel = @{
    Channel   = "Max Licensed VMs"
    Value     = $maxVms
    Unit      = "Count"
    LimitMode = 0
}
$sensorResult += $sensorChannel

$sensorChannel = @{
    Channel   = "Total VMs in Use"
    Value     = $totalVms
    Unit      = "Count"
    LimitMode = 0
}
$sensorResult += $sensorChannel

# Combine all messages into one sensor message.
$sensorMessage = "VPG: $vpgMsg; VRA: $vraMsg; License: $licenseMsg; Alerts: $alertsMsg"
Set-PRTGResultMessage -PRTGResultSet $sensorResult -Message $sensorMessage

# Output the final sensor result with UTF8 encoding.
#[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[string]$sensorResult
