# PRTG Nutanix Alerts and Health Sensor

This repository contains a custom PowerShell sensor for [PRTG Network Monitor](https://www.paessler.com/prtg) designed to monitor Nutanix Cluster alerts and derive a cluster health score. The sensor retrieves unresolved alerts using the Nutanix PowerShell cmdlets, classifies them into critical and warning categories, and outputs multiple channels for PRTG to display, including:

- **Critical Alerts**
- **Warning Alerts**
- **Critical Alerts Acknowledged**
- **Warning Alerts Acknowledged**
- **Total Alerts**
- **Acknowledged Alerts**
- **Derived Cluster Health Score** (0 = Good, 1 = Warning, 2 = Critical)

This sensor leverages PRTG-supplied environment variables for configuration, making it straightforward to integrate into your PRTG environment.

## Features

- **Alert Classification:** Separates unresolved alerts into critical and warning types.
- **Health Derivation:** Calculates an overall cluster health score based on the alert severity.
- **PRTG Integration:** Outputs results in JSON format for direct ingestion by PRTG.
- **Easy Credential Handling:** Uses PRTG environment variables to pass credentials to the Nutanix cluster.

## Prerequisites

- **PowerShell v5.1 or later:** This script is written in PowerShell.
- **Nutanix PowerShell Cmdlets:**  
  Ensure the Nutanix PowerShell modules are installed. By default, the script imports the modules from:
  ```
  C:\Program Files (x86)\Nutanix Inc\NutanixCmdlets\powershell\import_modules\ImportModules.PS1
  ```
  Adjust the path in the script if necessary.
- **PRTG Network Monitor:** This script is intended to run as a custom sensor within PRTG.
- **Environment Variables:**  
  When run by PRTG, make sure that the following environment variables are set:
  - `prtg_host` – Hostname or IP address of the Nutanix Cluster.
  - `prtg_windowspassword` – Plain text password for authentication.
  - `prtg_windowsuser` – Username for authentication.
  - `prtg_windowsdomain` (optional) – Domain (if applicable).

## Installation

1. **Clone or Download the Repository**
   ```bash
   git clone https://github.com/yourusername/PRTG_NutanixAlertsAndHealthSensor.git
   ```
2. **Copy the Script to Your PRTG Custom Sensors Directory**  
   Place `PRTG_NutanixAlertsAndHealthSensor.ps1` into your PRTG custom sensor script directory on the PRTG server.
3. **Verify Module Path**  
   Ensure the Nutanix PowerShell modules installed on your system match the import path in the script. Modify the path in the script if needed.
4. **Configure Environment Variables in PRTG**  
   In your PRTG Sensor settings, ensure the aforementioned environment variables are set.

## Usage

The sensor is intended to be executed automatically by PRTG. When running, it:
- Imports the required Nutanix modules.
- Connects to the specified Nutanix Cluster using provided credentials.
- Retrieves unresolved alerts and computes a derived cluster health score.
- Outputs results in JSON format that PRTG interprets as sensor channels.

For testing or debugging purposes, you can run the script manually from PowerShell:
```powershell
.\PRTG_NutanixAlertsAndHealthSensor.ps1 -ComputerName "YourNutanixCluster" -Credential (Get-Credential)
```

## Configuration

Within `PRTG_NutanixAlertsAndHealthSensor.ps1`, you can customize the following:
- **Thresholds for Alerts:**
  ```powershell
  [double]$CritThreshold = 0.4,
  [double]$WarnThreshold = 0.4,
  ```
- **Alert Severity Mapping:**  
  The script processes alerts with `kCritical` and `kWarning` severity levels. Expand or adjust the `switch` statement if additional classification is required.
- **Derived Health Logic:**  
  The derived health score is based on the absence or presence of warnings and critical alerts. You can modify this logic to better suit your environment.

## Troubleshooting

- **Credential Issues:**  
  If you encounter errors related to credential conversion, verify that:
  - The environment variable `prtg_windowspassword` contains the correct plain text password.
  - The PRTG environment variables for credentials (`prtg_windowsuser` and `prtg_windowsdomain`) are correctly set.
- **Module Import Errors:**  
  Ensure the Nutanix PowerShell modules are installed in the correct path, and adjust the import path in the script if needed.
- **Unexpected Sensor Results:**  
  If the sensor output does not match the expected counts, confirm that the Nutanix API is returning the expected severity values (e.g., `kCritical` or `kWarning`).

## Contributing

Contributions, improvements, and bug fixes are welcome! Please open an issue or submit a pull request if you have suggestions or encounter any problems.

## License

This project is licensed under the MIT License. See the [LICENSE](./../LICENSE) file for details.

## Acknowledgements

- **Nutanix Inc.** for their APIs and PowerShell modules.
- **Paessler AG** for PRTG Network Monitor, which makes monitoring robust and accessible.
