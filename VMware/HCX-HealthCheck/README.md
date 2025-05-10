# PRTG Custom Sensor for HCX Monitoring

This repository contains a PowerShell-based custom sensor for PRTG. It retrieves alerts from the HCX Cloud Connector or HCX Cloud Manager, monitors the status of HCX Service Mesh, and checks HCX Interconnect status. The sensor outputs the results in a JSON format compatible with PRTG.

## Overview

The sensor performs the following tasks:

- Retrieves HCX alerts via REST API using `curl.exe`.
- Counts and categorizes alerts by severity (Critical, Warning, and Informational).
- Monitors HCX Service Mesh status using PowerCLI.
- Checks HCX Interconnect and Tunnel statuses.
- Generates a consolidated output message that details any detected issues.
- Outputs various channels (alert counts, service mesh status, and interconnect information) in a format that PRTG can process.

## Prerequisites

- **PowerShell:** Run the script in an environment with PowerShell.
- **PowerCLI:** The script leverages PowerCLI commands (e.g., `Connect-HCXServer`, `Get-HCXServiceMesh`, and `Get-HCXInterconnectStatus`). Ensure that PowerCLI is installed and properly configured.
- **Network Access:** The machine running this sensor must have network connectivity to the target HCX Manager/Connector.
- **PRTG Environment:**  
  The sensor is designed to run within a PRTG environment. When a device under PRTG is configured with Windows device credentials, the values for `prtg_windowsuser` and `prtg_windowspassword` are automatically derived from those settings. These environment variables are then used by the script to build a credential if one is not manually provided.
- **Curl:** The script uses `curl.exe` to interact with the HCX REST API. This tool is available by default on many systems or can be installed separately.

## Script Parameters

- **`-hcx_manager`**:  
  Specifies the HCX Manager host. By default, it takes the value from the `prtg_host` environment variable.

- **`-critThreshold` and `-warnThreshold`**:  
  These thresholds define the maximum allowed counts for critical and warning alerts before an error is reported in PRTG.

- **`-Credential`**:  
  Optionally pass a PSCredential object. If not provided, the script will automatically use the credentials derived from the PRTG device's Windows credential settings (i.e., `prtg_windowsuser` and `prtg_windowspassword`).

For example, to run the sensor manually:  
```powershell
.\hcx_sensor.ps1 -hcx_manager <HCX_Manager_IP> -Credential (Get-Credential)
```

If the required PRTG environment variables are set (through the device's Windows credentials), you may omit the `-Credential` parameter.

## How It Works

1. **Initialization:**  
   The script starts by collecting credentials either from environment variables (which are populated automatically using the device's Windows credentials in PRTG) or via command parameters. It sets the error preference and adjusts process priority to avoid impacting other system services.
   
2. **HCX API Authentication:**  
   It retrieves an HCX API session token by posting JSON credentials to the HCX sessions API using `curl.exe`.

3. **Alert Retrieval and Parsing:**  
   The script fetches alerts, categorizes them by severity, and aggregates alert messages.

4. **Service Mesh and Interconnect Monitoring:**  
   Using PowerCLI, it assesses the status of the Service Mesh and Interconnect components. It reports any services that are down or partially functional (i.e., issues in tunnels).

5. **Output for PRTG:**  
   The sensor creates multiple result channels including counts for critical, warning, and informational alerts, as well as Service Mesh and Interconnect status. The final output is a JSON object that PRTG interprets to display the sensor data.

## Sample Output

An example of the sensor output is shown below:

```json
{
  "prtg": {
    "result": [
      {"Channel": "Critical Alert", "Value": 0, "Unit": "Count", "LimitMode": "1", "LimitMaxError": 0.4},
      {"Channel": "Warn Alert", "Value": 0, "Unit": "Count", "LimitMode": "1", "LimitMaxError": 0.4},
      {"Channel": "Info Alert", "Value": 0, "Unit": "Count", "LimitMode": "0"},
      {"Channel": "Total Alerts", "Value": 0, "Unit": "Count", "LimitMode": "0"},
      {"Channel": "Service Mesh Down", "Value": 0, "Unit": "Count", "LimitMode": "1", "LimitMaxError": 0},
      {"Channel": "Interconnect Down", "Value": 0, "Unit": "Count", "LimitMode": "1", "LimitMaxError": 0},
      {"Channel": "Interconnect Tunnel Down", "Value": 0, "Unit": "Count", "LimitMode": "1", "LimitMaxError": 0}
    ],
    "text": "No Alerts | All HCXServiceMesh is UP"
  }
}
```

## Usage Tips

- **Environment Variables:**  
  Utilize PRTG's device Windows credentials, which automatically set the `prtg_windowsuser` and `prtg_windowspassword` environment variables. This practice simplifies credential management and enhances security by avoiding manual credential input.

- **Threshold Configuration:**  
  Adjust `-critThreshold` and `-warnThreshold` based on your operational requirements to fine-tune the sensor’s sensitivity.

- **Logging & Debugging:**  
  The script stops on errors and sends error messages directly to PRTG. Check PowerShell error messages carefully for troubleshooting network, authentication, or API issues.

## Contributing

Contributions are welcome! If you have suggestions or improvements, please submit an issue or a pull request. Enhancements that improve clarity, performance, or add functionality are highly appreciated.

## License

This project is open source. Please refer to the [LICENSE](https://github.com/akbarraen/Custom-PRTG-Sensor-Scripts/blob/main/LICENSE) file for details.
