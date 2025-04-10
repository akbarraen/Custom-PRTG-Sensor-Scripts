# PRTG SimpliVity Custom Sensor Script

## Overview

This PowerShell script is designed to function as a custom sensor for [PRTG Network Monitor](https://www.paessler.com/prtg). It monitors **HPE SimpliVity clusters** and provides key insights into cluster health, storage usage, and arbiter connectivity. The results are displayed as distinct channels in PRTG, allowing for better management and visibility of your SimpliVity environment.

## Features

- **Cluster Space Usage**: Reports the percentage of allocated capacity in use.
- **Cluster Health**: Evaluates the health status of OVCs within the cluster.
- **Arbiter Status**: Checks connectivity with the arbiter.
- **Disk Health**: Ensures all disks in the cluster are functioning correctly.
- **Custom Thresholds**: Supports configurable warning and critical thresholds.

## Prerequisites

To use this script, ensure the following requirements are met:

- **Modules**: 
  - [PRTGResultSet](https://www.powershellgallery.com/packages/PRTGResultSet)
  - [HPESimpliVity](https://www.powershellgallery.com/packages/HPESimpliVity)
- **PowerShell**: Version 5.1 or later.
- **Permissions**: Ensure the script is executed with proper credentials to access the SimpliVity environment.
- **PRTG**: You must have an active PRTG instance where this script will be used as a custom sensor.

## Installation

1. Clone or download this repository.
2. Ensure that the required modules (`PRTGResultSet` and `HPESimpliVity`) are installed on the system running the script:
   ```powershell
   Install-Module -Name PRTGResultSet
   Install-Module -Name HPESimpliVity
   ```
3. Place the script file (`PRTG-Simplivity-CustomSensor.ps1`) in a directory accessible by the PRTG probe system.

## Usage

### Adding the Script as a PRTG Custom Sensor

1. Log in to your PRTG web interface.
2. Navigate to the device where you want to add the sensor.
3. Click **Add Sensor** and select **EXE/Script Advanced**.
4. Configure the sensor:
   - **EXE/Script File**: Select `PRTG-Simplivity-CustomSensor.ps1`.
   - **Parameters**: You can pass parameters (if needed) directly through the PRTG sensor settings.
   - **Timeout**: Ensure the script execution time is within the timeout period configured in PRTG.
5. Save the sensor. It will now execute and report the results for SimpliVity monitoring.

### Script Parameters

- **`-ComputerName`**: The hostname or IP address of the SimpliVity OVC (default: `PRTG` environment variable).
- **`-critThreshold`**: Critical threshold for space usage percentage (default: `80`).
- **`-warnThreshold`**: Warning threshold for space usage percentage (default: `70`).
- **`-Credential`**: Optional parameter to manually specify login credentials if not retrieved from the PRTG environment.

Example usage (PowerShell):
```powershell
.\PRTG-Simplivity-CustomSensor.ps1 -ComputerName "OVC.example.com" -critThreshold 85
```

## Output

The script returns the following channels to PRTG:

| Channel                    | Unit    | Description                                     |
|----------------------------|---------|-------------------------------------------------|
| SimpliVity Space Usage     | Percent | Percentage of allocated capacity used.         |
| SimpliVity Cluster Health  | Count   | Value of `0` (healthy) or `1` (issues present).|
| Arbiter Status             | Count   | Value of `0` (connected) or `1` (disconnected).|
| SimpliVity Disks Health    | Count   | Value of `0` (healthy) or `1` (issues present).|

## Example Output Message

```
SimpliVity Space Usage is at 75%, All OVCs are ALIVE, Arbiter Connected, All disks in the cluster are healthy.
```

## License

This project is licensed under the [MIT License](./../LICENSE). See the `LICENSE` file for details.

---
