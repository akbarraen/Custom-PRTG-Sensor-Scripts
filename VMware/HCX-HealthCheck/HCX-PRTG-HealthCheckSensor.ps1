<#
.SYNOPSIS
Retrieves alerts from HCX Cloud Connector or HCX Cloud Manager and monitors ServiceMesh and Interconnect status.
#>

# Define script parameters
param (
    # Computer to connect to. Normally don't need to specify this.
    [String]$hcx_manager = $ENV:prtg_host,
    [double]$critThreshold = 0.4,
    [double]$warnThreshold = 0.4,
    # Manually specify Credential if not provided via environment variables
    [Parameter(ParameterSetName = "Credential")][PSCredential]$Credential
)

# If PRTG environment variables exist then use them for credential
if ($ENV:prtg_windowspassword) {
    $username = $ENV:prtg_windowsuser
    $Password = $ENV:prtg_windowspassword
}

# If no Credential was passed in, then create one using the available username and password
if (-not $Credential -and $username -and $Password) {
    $securePass = ConvertTo-SecureString $Password -AsPlainText -Force  
    $Credential = New-Object System.Management.Automation.PSCredential($username, $securePass)
}

# In case of errors, output the error to PRTG directly
$ErrorActionPreference = 'Stop'
trap { Stop-PRTGScript $PSItem }

# Drop process priority to avoid competing with other services
(Get-Process -Id $pid).PriorityClass = 'BelowNormal'

# Avoid unnecessary output and certificate issues for PowerCLI commands
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP:$false -Confirm:$false | Out-Null
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

# Create a PowerCLI session with the remote computer (HCX Manager)
$sensorPoCLISession = Connect-HCXServer -Server $hcx_manager -Credential $Credential -Force
if (-not $sensorPoCLISession) { throw "Connection to $hcx_manager failed for an unknown reason." }

#------------------------------------------------------------
# Get the HCX API session token
#------------------------------------------------------------

# Use curl.exe to get the HCX session token. We post JSON credentials to the sessions API.
$sessionUrl = "https://$($hcx_manager)/hybridity/api/sessions"
$body = "{\""username\"":\""$username\"", \""password\"":\""$Password\""}"
$sessionResponse = curl.exe -i -s -k -o NUL -D - -X POST $sessionUrl -H "accept: application/json" -H "Content-Type: application/json" -d $body

# Extract the token from the header 'x-hm-authorization'
$hmAuthToken = ($sessionResponse -split "`r`n" | Where-Object { $_ -like "x-hm-authorization:*" }) -replace "x-hm-authorization:\s*", ""

#------------------------------------------------------------
# Get the HCX Alerts and parse counts
#------------------------------------------------------------

$alertsUrl = "https://$($hcx_manager)/hybridity/api/alerts?action=query"
$alertsResponse = curl.exe -s -k -X POST $alertsUrl `
    -H "accept: application/json" -H "x-hm-authorization: $hmAuthToken" `
    -H "Content-Type: application/json" -d "{}"
$alerts = $alertsResponse | ConvertFrom-Json

# Initialize counters and messages for alerts
[int]$critAlert  = 0
[int]$warnAlert  = 0
[int]$infoAlert  = 0
$critMsg = @()
$warnMsg = @()

foreach ($alert in $alerts.items) {
    switch ($alert.severity) {
        "CRITICAL" {
            $critAlert++
            $critMsg += $alert.message
            break
        }
        "WARNING" {
            $warnAlert++
            $warnMsg += $alert.message
            break
        }
        Default {
            $infoAlert++
        }
    }
}

# Build the sensor message based on alert counts
if ($critAlert -gt 0 -and $warnAlert -gt 0) {
    $sensorMessage = "$critAlert Critical Alert(s): $(($critMsg -join ', ')); $warnAlert Warning Alert(s): $(($warnMsg -join ', '))"
} elseif ($critAlert -gt 0) {
    $sensorMessage = "$critAlert Critical Alert(s): $(($critMsg -join ', '))"
} elseif ($warnAlert -gt 0) {
    $sensorMessage = "$warnAlert Warning Alert(s): $(($warnMsg -join ', '))"
} else {
    $sensorMessage = "No Alerts"
}

#------------------------------------------------------------
# HCX Service Mesh Status Monitoring
#------------------------------------------------------------

# Fetch the service mesh status using PowerCLI
$serviceMesh = (Get-HCXServiceMesh).ServiceStatus
[int]$downServicesCount = 0
$serviceMeshMsg = @()
foreach ($svc in $serviceMesh) {
    if ($svc.Status -ne "up") {
        $downServicesCount++
        $serviceMeshMsg += "$($svc.ServiceName) is down"
    }
}

if ($downServicesCount -gt 0) {
    $sensorMessage += " | Service Mesh Alerts: $(($serviceMeshMsg -join ', '))."
}
else {$sensorMessage += " | All HCX Service Mesh is Operational"}

#------------------------------------------------------------
# HCX Interconnect Status Monitoring
#------------------------------------------------------------

# Fetch the interconnect statuses using PowerCLI
$interconnectStatus = Get-HCXInterconnectStatus
[int]$interconnectDownCount = 0
[int]$tunnelDownCount = 0
$interconnectMsg = @()
$tunnelMsg = @()

foreach ($ic in $interconnectStatus) {
    if ($ic.Status -ne "up") {
        $interconnectDownCount++
        $interconnectMsg += "$($ic.ServiceComponent) status is not up"
    }
    if ($ic.Tunnel -ne "up") {
        $tunnelDownCount++
        $tunnelMsg += "Tunnel for $($ic.ServiceComponent) is down"
    }
}

if ($interconnectDownCount -gt 0) {
    $sensorMessage += " | Interconnect Alerts: $(($interconnectMsg -join ', '))."
}
if ($tunnelDownCount -gt 0) {
    $sensorMessage += " | Tunnel Alerts: $(($tunnelMsg -join ', '))."
}

#------------------------------------------------------------
# Assemble PRTG Sensor Results
#------------------------------------------------------------

$sensorResult = New-PRTGResult

# Critical Alert Channel
$sensorResult += @{
    Channel       = "Critical Alert"
    Value         = $critAlert
    Unit          = "Count"
    LimitMode     = "1"
    LimitMaxError = $critThreshold
}

# Warning Alert Channel
$sensorResult += @{
    Channel       = "Warn Alert"
    Value         = $warnAlert
    Unit          = "Count"
    LimitMode     = "1"
    LimitMaxError = $warnThreshold
}

# Info Alert Channel
$sensorResult += @{
    Channel   = "Info Alert"
    Value     = $infoAlert
    Unit      = "Count"
    LimitMode = "0"
}

# Total Alerts Channel (summing all alerts)
$sensorResult += @{
    Channel   = "Total Alerts"
    Value     = $critAlert + $warnAlert + $infoAlert
    Unit      = "Count"
    LimitMode = "0"
}

# Service Mesh Down Channel
$sensorResult += @{
    Channel       = "Service Mesh Down"
    Value         = $downServicesCount
    Unit          = "Count"
    LimitMode     = "1"
    LimitMaxError = 0
}

# Interconnect Down Channel
$sensorResult += @{
    Channel       = "Interconnect Down"
    Value         = $interconnectDownCount
    Unit          = "Count"
    LimitMode     = "1"
    LimitMaxError = 0
}

# Interconnect Tunnel Down Channel
$sensorResult += @{
    Channel       = "Interconnect Tunnel Down"
    Value         = $tunnelDownCount
    Unit          = "Count"
    LimitMode     = "1"
    LimitMaxError = 0
}

# End the PowerCLI session to free up resources
Disconnect-HCXServer -Server $hcx_manager -Confirm:$false

# Add the sensor message to the PRTG result set for alarm details
Set-PRTGResultMessage -PRTGResultSet $sensorResult -Message $sensorMessage

# Output the sensor results
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[string]$sensorResult
