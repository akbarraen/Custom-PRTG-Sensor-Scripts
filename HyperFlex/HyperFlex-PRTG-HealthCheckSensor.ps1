<#
.SYNOPSIS
    PRTG Custom Sensor for Monitoring HyperFlex Cluster Using API

.DESCRIPTION
    This PowerShell script acts as a custom sensor for PRTG to monitor the health of a HyperFlex cluster.
    It authenticates with the HyperFlex API via curl.exe to gather key metrics:
      • Cluster State
      • zkHealth
      • Resiliency State
      • Space Status
      • Space Usage Percentage

    The results are formatted using the PRTGResultSet module so that PRTG can trigger alerts based 
    on custom thresholds (for example, alerting if space usage exceeds 76%). Ensure that both the 
    PRTGResultSet module and curl.exe are available on your Windows system and are accessible in the PATH.
    
.NOTES
    Developed by: Akbar Raen
    Version: 1.0
    Date: April , 2025
#>

param (
    # The computer name is typically provided by PRTG.
    [String]$HXCluster_IP = $ENV:prtg_host,
    $critThreshold = 0.4,
    $warnThreshold = 0.4,
    # Optionally, specify a credential.
    [Parameter(ParameterSetName = "Credential")][PSCredential]$Credential,
    $User,
    $Password
)

#---------------------------------------------
# Dependency Checks
#---------------------------------------------
if (-not (Get-Module -Name PRTGResultSet -ListAvailable)) {
    Write-Error "PRTGResultSet module not found. Please install it before using this script."
    exit 1
}
Import-Module PRTGResultSet -ErrorAction Stop

if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    Write-Error "curl.exe not found in system PATH. Please ensure curl.exe is installed."
    exit 1
}


#If there is a problem, output the error to PRTG Directly
$ErrorActionPreference = 'Stop'
trap { Stop-PRTGScript $PSItem }

#Drop process priority to avoid competing with services
(Get-Process -Id $pid).PriorityClass = 'BelowNormal'

#Obtain Credentials from PRTG Environment Variables if possible
if ($ENV:prtg_windowspassword) {
	$User = $ENV:prtg_windowsuser
	if ($ENV:prtg_windowsdomain) {
		$User = $ENV:prtg_windowsdomain, $user -join '\'
	}
	$Password = $ENV:prtg_windowspassword 
}

#Fix For: The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# Initialize alert messages container.
$alertMessages = @()

#---------------------------------------------
# Get API Token from the HyperFlex Cluster IP 
#---------------------------------------------
try {
    $body = '{"username": "' + $User + '", "password": "' + $Password + '"}' | ConvertTo-Json
    $CurlCommand = "curl.exe -s -k -X POST `"https://$HXCluster_IP/aaa/v1/auth?grant_type=password&revoke_prev_tokens=true`" " +
                "--header `"Content-Type: application/json`" " +
                "--header `"Accept: application/json`" " +
                "-d '" + $body + "'"

    $TokenResponse = Invoke-Expression $CurlCommand | ConvertFrom-Json
    $SessionToken = $TokenResponse.access_token
    $SessionTokenType = $TokenResponse.token_type

    #Get HyperFlex Cluster ID
    $CurlCommand = "curl.exe -s -k --location `"https://$HXCluster_IP/coreapi/v1/clusters`" " + `
                    "--header `"Accept: application/json`" " + `
                    "--header `"Authorization: $SessionTokenType $SessionToken`""
    $ClusterResponse = Invoke-Expression $CurlCommand | ConvertFrom-Json
    $ClusterId = $ClusterResponse.uuid
}
Catch{Stop-PRTGScript "Authentication error: $_"}

#============================================================================================================#
#Get HyerpeFlex Cluster State, Health, ResiliencyState
try {
    $CurlCommand = "curl.exe -s -k --location `"https://$HXCluster_IP/coreapi/v1/clusters/$ClusterId/health`" " + `
                "--header `"Accept: application/json`" " + `
                "--header `"Authorization: $SessionTokenType $SessionToken`""

    $ClusterResponse = Invoke-Expression $CurlCommand | ConvertFrom-Json
    $ClusterState = $ClusterResponse.state # Expected: 'ONLINE'
    $zkHealth = $ClusterResponse.zkHealth # Expected: 'ONLINE'
    $resiliencyState = $ClusterResponse.resiliencyDetails.resiliencyState   # Expected: 'HEALTHY'
}
catch {
    $alertMessages += "Error retrieving Cluster Health data: $_"
    $ClusterState    = "ERROR"
    $zkHealth        = "ERROR"
    $resiliencyState = "ERROR"
}
#============================================================================================================#
# Get HyperFlex Cluster stats
try {
    $CurlCommand = "curl.exe -s -k --location `"https://$HXCluster_IP/coreapi/v1/clusters/$ClusterId/stats`" " + `
                    "--header `"Accept: application/json`" " + `
                    "--header `"Authorization: $SessionTokenType $SessionToken`""
    $statsResponse = Invoke-Expression $CurlCommand | ConvertFrom-Json
    $spaceStatus        = $statsResponse.spaceStatus      # Expected: NORMAL
    $totalCapacityBytes = $statsResponse.totalCapacityInBytes
    $usedCapacityBytes  = $statsResponse.usedCapacityInBytes

    if ($totalCapacityBytes -gt 0) {
        $spaceUsagePercent = ($usedCapacityBytes / $totalCapacityBytes) * 100
    } else {
        $spaceUsagePercent = 0
    }
}
catch {
    $alertMessages += "Error retrieving Cluster Stats data: $_"
    $spaceStatus       = "ERROR"
    $spaceUsagePercent = 0
}

#Evaluate Conditions for Each Channel (Set 1 = OK, 0 = Alert)
$clusterStateOK = if ($ClusterState -eq "ONLINE")    { 1 } else { 0 }
$zkHealthOK     = if ($zkHealth -eq "ONLINE")        { 1 } else { 0 }
$resiliencyOK   = if ($resiliencyState -eq "HEALTHY")  { 1 } else { 0 }
$spaceStatusOK  = if ($spaceStatus -eq "NORMAL")       { 1 } else { 0 }

# ----- Build Alert Messages -----
if ($ClusterState -ne "ONLINE") {
    $alertMessages += "Alert: Cluster state is $ClusterState."
}
if ($zkHealth -ne "ONLINE") {
    $alertMessages += "Alert: Current zkHealth is $zkHealth."
}
if ($resiliencyState -ne "HEALTHY") {
    $alertMessages += "Alert: Cluster resiliency is $resiliencyState."
}
if ($spaceStatus -ne "NORMAL") {
    $alertMessages += "Alert: Space status is $spaceStatus."
}
if ($spaceUsagePercent -ge 76) {
    $alertMessages += ("Alert: High space usage at {0:N2}%." -f $spaceUsagePercent)
}

if ($alertMessages.Count -gt 0) {
    $textMessage = $alertMessages -join " "
} else {
    $textMessage = "All systems nominal."
}

#============================================================================================================#
#Build the PRTG Result Set
$resultset = New-PRTGResult

# Channel for Cluster State
$resultset | Add-PRTGResult -Channel "Cluster State" `
                             -Value $clusterStateOK `
                             -CustomUnit "Status (1 = OK, 0 = Alert)"

# Channel for zkHealth
$resultset | Add-PRTGResult -Channel "zkHealth" `
                             -Value $zkHealthOK `
                             -CustomUnit "Status (1 = OK, 0 = Alert)"

# Channel for Resiliency
$resultset | Add-PRTGResult -Channel "Resiliency" `
                             -Value $resiliencyOK `
                             -CustomUnit "Status (1 = OK, 0 = Alert)"

# Channel for Space Status
$resultset | Add-PRTGResult -Channel "Space Status" `
                             -Value $spaceStatusOK `
                             -CustomUnit "Status (1 = OK, 0 = Alert)"

# Channel for Space Usage Percentage
$resultset | Add-PRTGResult -Channel "Space Usage %" `
                             -Value ([math]::Round($spaceUsagePercent,2)) `
                             -Unit "Percent" `
                             -LimitMaxError 76

# Set the Sensor Summary Text with the combined alerts (or OK message)
Set-PRTGResultMessage -PRTGResultSet $resultset -Message $textMessage

# ----- Output the PRTG XML Result -----
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[string]$resultset
