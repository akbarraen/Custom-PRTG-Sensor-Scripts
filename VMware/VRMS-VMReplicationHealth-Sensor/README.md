# PRTG vSphere Replication Health Sensor Script

## Overview

This PowerShell script is designed to function as a custom sensor for [PRTG Network Monitor](https://www.paessler.com/prtg). It monitors **vSphere Replication health**, fetching replication status and ensuring compliance across all configured VMs. The results are displayed as distinct channels in PRTG, enabling better visibility into replication performance and identifying potential failures.

## Features

- **Replication Health Check**: Monitors VM replication status across vSphere replication appliances.
- **RPO Violation Detection**: Flags VMs that exceed their defined recovery point objective.
- **Status Filtering**: Identifies VMs with critical replication failures outside valid states.
- **Custom Thresholds**: Configurable thresholds for warning and critical alerts.
- **Optimized Reporting**: Returns structured results with sensor messages for easy interpretation in PRTG.

## Prerequisites

To use this script, ensure the following requirements are met:

- **Modules**: 
  - [PRTGResultSet](https://www.powershellgallery.com/packages/PRTGResultSet)
  - vSphere Replication PowerShell Module
- **PowerShell**: Version 5.1 or later.
- **Permissions**: Ensure the script runs with proper credentials to access vSphere replication servers.
- **PRTG**: An active PRTG instance where this script will be used as a **custom sensor**.

## Installation

1. Clone or download this repository.
2. Ensure that the required modules (`PRTGResultSet` and vSphere Replication commands) are installed on the system running the script.
3. Place the script file (`Monitor_VMReplication.ps1`) in a directory accessible by the PRTG probe system.

## Usage

### Adding the Script as a PRTG Custom Sensor

1. Log in to your PRTG web interface.
2. Navigate to the **device** where you want to add the sensor.
3. Click **Add Sensor** and select **EXE/Script Advanced**.
4. Configure the sensor:
   - **EXE/Script File**: Select `Monitor_VMReplication.ps1`.
   - **Parameters**: You can pass parameters (if needed) directly through the PRTG sensor settings.
   - **Timeout**: Ensure the script execution time is within the timeout period configured in PRTG.
5. Save the sensor. It will now execute and report the results for replication monitoring.

### Script Parameters

- **`-ComputerName`**: The hostname or IP address of the vSphere Replication Appliance (default: `PRTG` environment variable).
- **`-critThreshold`**: Critical threshold for failing replications count (default: `0.4`).
- **`-warnThreshold`**: Warning threshold for failing replications count (default: `0.4`).
- **`-Credential`**: Optional parameter to manually specify login credentials if not retrieved from the PRTG environment.

Example usage (PowerShell):
```powershell
.\Monitor_VMReplication.ps1 -ComputerName "replication.example.com" -critThreshold 0.5
```

## Output

The script returns the following channels to PRTG:

| Channel                   | Unit    | Description                                     |
|---------------------------|--------|-------------------------------------------------|
| Replication Failures      | Count  | Number of VMs with non-compliant replication.  |
| Total Replications        | Count  | Total monitored replications.                   |

## Example Output Message

```
Replication Status is critical for the VMs: VM01, VM02, VM03
```

If all VMs are healthy:
```
All VMs replication are healthy
```

## License

This project is licensed under the [MIT License](https://github.com/akbarraen/Custom-PRTG-Sensor-Scripts/blob/main/LICENSE). See the `LICENSE` file for details.

---
