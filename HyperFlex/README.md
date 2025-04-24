# HyperFlex PRTG Custom Sensor

This repository contains a PowerShell script that functions as a custom sensor for [PRTG Network Monitor](https://www.paessler.com/prtg) to track the health and performance of Cisco HyperFlex clusters via its API. The script retrieves key metrics—including cluster state, zkHealth, resiliency, space status, and space usage percentage—and outputs the data in a format that PRTG understands. Alerts can be triggered based on custom thresholds, such as high space usage.

## Features

- **HyperFlex Cluster Monitoring:**  
  Retrieves the following metrics:
  - **Cluster State:** Expected to be "ONLINE"
  - **zkHealth:** Expected to be "ONLINE"
  - **Resiliency:** Expected to be "HEALTHY"
  - **Space Status:** Expected to be "NORMAL"
  - **Space Usage %:** With a threshold set so that values ≧76% trigger an alert

- **PRTG Integration:**  
  Uses the `PRTGResultSet` PowerShell module to create properly structured XML output for seamless integration with PRTG.

- **Robust API Authentication:**  
  Authenticates securely via `curl.exe` using provided credentials and supports environment variables passed by PRTG.

- **Error Handling & Alerting:**  
  The script detects issues in each metric and consolidates alert messages, allowing PRTG to display concise summaries of cluster health.

## Prerequisites

- **PowerShell:** Ensure you are running the script in a PowerShell environment.
- **curl.exe:** Must be installed and in your system PATH. You can download it from the [curl website](https://curl.se/windows/).
- **PRTGResultSet Module:**  
  The script depends on the `PRTGResultSet` module. Install it via PowerShell if available on the PowerShell Gallery or download it from your preferred source:
  ```powershell
  Install-Module -Name PRTGResultSet
  ```
- **HyperFlex Cluster Access:**  
  Valid HyperFlex API credentials (username and password) and the HyperFlex cluster IP address.

## Configuration

- **Environment Variables (Optional):**  
  If running within a PRTG environment, the script can automatically pick up credentials from the following environment variables:
  - `prtg_windowspassword`
  - `prtg_windowsuser`
  - `prtg_windowsdomain`

- **Command-Line Parameters:**  
  You can also pass credentials directly using the `-User` and `-Password` parameters:
  ```powershell
  .\hyperflex.ps1 -HXCluster_IP <HyperFlex_Cluster_IP> -User <username> -Password <password>
  ```

## Usage

Execute the script from PowerShell by supplying the required parameters. For example:

```powershell
.\hyperflex.ps1 -HXCluster_IP 192.168.1.100 -User myUser -Password myPassword
```

### Sample Output

When everything is configured correctly, you should see an output similar to the following JSON structure:

```json
{
  "prtg": {
    "result": [
      {"Channel": "Cluster State", "Value": 1, "CustomUnit": "Status (1 = OK, 0 = Alert)"},
      {"Channel": "zkHealth", "Value": 1, "CustomUnit": "Status (1 = OK, 0 = Alert)"},
      {"Channel": "Resiliency", "Value": 1, "CustomUnit": "Status (1 = OK, 0 = Alert)"},
      {"Channel": "Space Status", "Value": 1, "CustomUnit": "Status (1 = OK, 0 = Alert)"},
      {"Channel": "Space Usage %", "Value": 52.82, "Unit": "Percent", "LimitMaxError": 76}
    ],
    "text": "All systems nominal."
  }
}
```

## Script Overview

- **Authentication:**  
  The script uses `curl.exe` to first authenticate to the HyperFlex API and retrieve an access token. It then retrieves the cluster UUID required for subsequent API calls.

- **Data Collection:**  
  It fetches data from the following API endpoints:  
  - `/coreapi/v1/clusters/<ClusterId>/health` for health metrics.
  - `/coreapi/v1/clusters/<ClusterId>/stats` for space statistics.

- **Alert Evaluation:**  
  Metrics are validated against expected values. If a metric is outside its acceptable range, an alert is added to the summary message.

- **PRTG Format Output:**  
  The script prepares the output using the `PRTGResultSet` module to deliver properly formatted XML that integrates seamlessly with PRTG.

## Troubleshooting

- **Module Not Found Error:**  
  If you encounter an error related to `PRTGResultSet`, ensure the module is installed and accessible. Use:
  ```powershell
  Get-Module -ListAvailable -Name PRTGResultSet
  ```

- **curl.exe Not Found:**  
  Verify that `curl.exe` is in your system PATH by running:
  ```powershell
  curl.exe --version
  ```

- **SSL/TLS Issues:**  
  The script sets the appropriate TLS protocols and bypasses certificate validations if needed. However, ensure that your environment’s security policies allow for this or adjust accordingly.

## Contributing

Contributions and feedback are welcome! Please fork the repository and submit pull requests. When contributing, ensure that your changes maintain the PRTG sensor’s integration and functionality.

## License

This project is licensed under the [MIT License](https://github.com/akbarraen/Custom-PRTG-Sensor-Scripts/blob/main/LICENSE).

---

- **Developed by:** [Akbar Raen](https://github.com/akbarraen)
