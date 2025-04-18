# Zerto PRTG Monitoring Sensor

## Overview
This PowerShell script is a **custom sensor** for **PRTG Network Monitor** that collects various health metrics from a **Zerto replication environment** via its API. It provides monitoring for:

- **ZVM Monitoring** (alerts & errors)
- **VPG Health** (virtual protection groups)
- **VRA Monitoring** (replication appliances)
- **License Monitoring** (licensed vs. used VMs)

The script generates PRTG-compatible results, including performance metrics and alerts when critical thresholds are exceeded.

## Prerequisites
1. **PRTG Network Monitor** must be installed and configured.
2. **PowerShell** version **5.1 or later**.
3. **Zerto Linux Appliance (ZCA)** with API access enabled.
4. **Keycloak Client Credentials** for authentication.

## Keycloak Authentication Setup
To access the Zerto API, you must create a **Keycloak client** in the Zerto Appliance UI under **Keycloak Administration**. Follow the official Zerto guide:

➡ [Creating Keycloak Credentials](https://help.zerto.com/bundle/Linux.ZCA.HTML.10.0_U1/page/Creating_Keycloak_Credentials.htm)

### Steps:
1. Open **Keycloak Administration** at:
   ```
   https://<ZCA_Linux_Appliance>/auth
   ```
2. Navigate to **Clients** → **Create Client**.
3. Configure **client_id** and **client_secret**.
4. Assign necessary permissions for API access.

## Usage
Run the script with the required parameters:

```sh
./Zerto-Monitoring-Sensor.ps1 -ZVM_IP <ZCA Linux Appliance IP> -ClientID <your-client-id> -ClientSecret <your-client-secret>
```

### Example:
```sh
./Zerto-Monitoring-Sensor.ps1 -ZVM_IP 10.0.10.11 -ClientID "monitoringClient" -ClientSecret "superSecretKey"
```

## Output Metrics
The script provides **PRTG-compatible results** across the following monitoring categories:

| Metric                     | Description                                      |
|----------------------------|--------------------------------------------------|
| **ZVM Alerts**             | Counts high-severity alerts.                     |
| **VPG Health**             | Reports the status of Virtual Protection Groups. |
| **VRA Total**              | Number of Virtual Replication Appliances.        |
| **Healthy VRAs**           | Count of healthy VRAs.                           |
| **Unhealthy VRAs**         | Count of unhealthy VRAs (includes names).        |
| **VRA Memory (GB)**        | Total memory allocated to VRAs.                  |
| **VRA CPUs**               | Total CPUs allocated to VRAs.                    |
| **Zerto License Status**   | Verifies if usage exceeds licensed VMs.          |
| **Max Licensed VMs**       | Maximum VMs allowed by license.                  |
| **Total VMs in Use**       | Number of VMs currently protected.               |

### License Alerts
If the **Total VMs Used** exceeds the **Max Licensed VMs**, an alert will be triggered in PRTG:

```
Zerto has license for 15 VMs, but usage is 18 VMs.
```

## Contributions
Feel free to contribute enhancements! Create a pull request or open an issue if you encounter any problems.

## License
This project is licensed under **[MIT License](https://github.com/akbarraen/Custom-PRTG-Sensor-Scripts/blob/main/LICENSE)**.
