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
    Date: April 19, 2025
#>

param (
    # HyperFlex Cluster IP – typically provided by PRTG.
    [String]$HXCluster_IP = $ENV:prtg_host,
    # Critical and warning threshold values for space usage.
    [double]$critThreshold = 0.4,
    [double]$warnThreshold = 0.4,
    # Optionally, specify a credential.
    [Parameter(ParameterSetName = "Credential")][PSCredential]$Credential,
    [String]$User,
    [String]$Password
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

# Set error action preference and register a trap for error handling.
$ErrorActionPreference = 'Stop'
trap { Stop-PRTGScript $_ }

# Lower process priority so this script does not compete with more critical services.
(Get-Process -Id $pid).PriorityClass = 'BelowNormal'

#---------------------------------------------
# Credentials Handling
#---------------------------------------------
if ($ENV:prtg_windowspassword) {
    $User = $ENV:prtg_windowsuser
    if ($ENV:prtg_windowsdomain) {
        $User = "$ENV:prtg_windowsdomain\$User"
    }
    $Password = $ENV:prtg_windowspassword 
}

#---------------------------------------------
# Allow Insecure SSL Connections (for self-signed certificates)
#---------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor `
                                              [Net.SecurityProtocolType]::Tls11 -bor `
                                              [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

#---------------------------------------------
# Function: Invoke-CurlApi
# Builds a robust curl command using argument arrays.
#---------------------------------------------
function Invoke-CurlApi {
    param (
        [Parameter(Mandatory)]
        [string]$Url,
        [string]$Method = "GET",
        [hashtable]$Headers,
        [string]$Body
    )
    $arguments = @("-s", "-k", "-X", $Method, $Url)
    if ($Headers) {
        foreach ($key in $Headers.Keys) {
            $arguments += "--header"
            $arguments += "$key: $($Headers[$key])"
        }
    }
    if ($Body) {
        $arguments += "-d"
        $arguments += $Body
    }
    return & curl.exe @arguments
}

# Initialize alert messages container.
$alertMessages = @()

#---------------------------------------------
# Authenticate with HyperFlex API and retrieve the Cluster ID
#---------------------------------------------
try {
    $authPayload = @{ username = $User; password = $Password } | ConvertTo-Json -Compress
    $authUrl     = "https://$HXCluster_IP/aaa/v1/auth?grant_type=password&revoke_prev_tokens=true"
    $tokenResponse = Invoke-CurlApi -Url $authUrl `
                                    -Method "POST" `
                                    -Headers @{ "Content-Type" = "application/json"; "Accept" = "application/json" } `
                                    -Body $authPayload | ConvertFrom-Json
    $SessionToken    = $tokenResponse.access_token
    $SessionTokenType= $tokenResponse.token_type

    $clustersUrl = "https://$HXCluster_IP/coreapi/v1/clusters"
    $clusterResponse = Invoke-CurlApi -Url $clustersUrl `
                                      -Headers @{ "Accept" = "application/json"; "Authorization" = "$SessionTokenType $SessionToken" } | ConvertFrom-Json
    $ClusterId = $clusterResponse.uuid
}
catch {
    Stop-PRTGScript "Authentication error: $_"
}

#---------------------------------------------
# Retrieve Cluster Health Metrics
#---------------------------------------------
try {
    $healthUrl = "https://$HXCluster_IP/coreapi/v1/clusters/$ClusterId/health"
    $healthResponse = Invoke-CurlApi -Url $healthUrl `
                                     -Headers @{ "Accept" = "application/json"; "Authorization" = "$SessionTokenType $SessionToken" } | ConvertFrom-Json
    $ClusterState   = $healthResponse.state                   # Expected: 'ONLINE'
    $zkHealth       = $healthResponse.zkHealth                  # Expected: 'ONLINE'
    $resiliencyState= $healthResponse.resiliencyDetails.resiliencyState  # Expected: 'HEALTHY'
}
catch {
    $alertMessages += "Error retrieving Cluster Health data: $_"
    $ClusterState    = "ERROR"
    $zkHealth        = "ERROR"
    $resiliencyState = "ERROR"
}

$clusterStateOK = if ($ClusterState -eq "ONLINE")    { 1 } else { 0 }
$zkHealthOK     = if ($zkHealth -eq "ONLINE")        { 1 } else { 0 }
$resiliencyOK   = if ($resiliencyState -eq "HEALTHY")  { 1 } else { 0 }

#---------------------------------------------
# Retrieve Cluster Stats Metrics
#---------------------------------------------
try {
    $statsUrl = "https://$HXCluster_IP/coreapi/v1/clusters/$ClusterId/stats"
    $statsResponse = Invoke-CurlApi -Url $statsUrl `
                                    -Headers @{ "Accept" = "application/json"; "Authorization" = "$SessionTokenType $SessionToken" } | ConvertFrom-Json
    $spaceStatus        = $statsResponse.spaceStatus      # Expected: 'NORMAL'
    $totalCapacityBytes = $statsResponse.totalCapacityInBytes
    $usedCapacityBytes  = $statsResponse.usedCapacityInBytes

    $spaceUsagePercent = 0
    if ($totalCapacityBytes -gt 0) {
        $spaceUsagePercent = ($usedCapacityBytes / $totalCapacityBytes) * 100
    }
}
catch {
    $alertMessages += "Error retrieving Cluster Stats data: $_"
    $spaceStatus       = "ERROR"
    $spaceUsagePercent = 0
}

$spaceStatusOK  = if ($spaceStatus -eq "NORMAL") { 1 } else { 0 }

#---------------------------------------------
# Build Alert Messages
#---------------------------------------------
if ($ClusterState -ne "ONLINE")     { $alertMessages += "Alert: Cluster state is $ClusterState." }
if ($zkHealth -ne "ONLINE")         { $alertMessages += "Alert: zkHealth is $zkHealth." }
if ($resiliencyState -ne "HEALTHY")   { $alertMessages += "Alert: Resiliency is $resiliencyState." }
if ($spaceStatus -ne "NORMAL")       { $alertMessages += "Alert: Space status is $spaceStatus." }
if ($spaceUsagePercent -ge 76)        { $alertMessages += ("Alert: High space usage at {0:N2}%." -f $spaceUsagePercent) }

$textMessage = if ($alertMessages.Count -gt 0) { $alertMessages -join " " } else { "All systems nominal." }

#---------------------------------------------
# Build the PRTG Result Set and Output in XML Format
#---------------------------------------------
$resultset = New-PRTGResult

$resultset | Add-PRTGResult -Channel "Cluster State" -Value $clusterStateOK -CustomUnit "Status (1 = OK, 0 = Alert)"
$resultset | Add-PRTGResult -Channel "zkHealth"      -Value $zkHealthOK     -CustomUnit "Status (1 = OK, 0 = Alert)"
$resultset | Add-PRTGResult -Channel "Resiliency"    -Value $resiliencyOK   -CustomUnit "Status (1 = OK, 0 = Alert)"
$resultset | Add-PRTGResult -Channel "Space Status"  -Value $spaceStatusOK  -CustomUnit "Status (1 = OK, 0 = Alert)"
$resultset | Add-PRTGResult -Channel "Space Usage %" -Value ([math]::Round($spaceUsagePercent,2)) -Unit "Percent" -LimitMaxError 76

Set-PRTGResultMessage -PRTGResultSet $resultset -Message $textMessage

# Output the result as UTF-8 XML.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[string]$resultset
