# NSX-T Alarms PRTG Sensor Using Curl

This repository contains a PowerShell script that retrieves open alarms from an NSX Manager via its API using **curl** and formats the data for a custom PRTG sensor. The script distinguishes between:

- **Red Alarms**: Alarms with severity **HIGH** or **CRITICAL**.
- **Yellow Alarms**: Alarms with severity **MEDIUM** or **LOW**.

The output includes individual channels for Red Alarms, Yellow Alarms, and Total Alarms, along with a message summarizing the information.

## Features

- **Curl-Based API Calls**: Uses curl to retrieve alarm data securely.
- **Categorized Alarm Processing**: Splits alarms into red and yellow categories for enhanced monitoring.
- **Flexible Credential Handling**: Accepts credentials via a `PSCredential` parameter or environment variables.
- **PRTG Sensor Compatibility**: Formats the output to integrate seamlessly with PRTG custom sensors.
- **Optimized Performance**: Sets process priority to minimize system impact while executing.

## Requirements

- **PowerShell**: Version 5.1 or later (or PowerShell Core 7+).
- **curl**: Ensure curl is installed at `C:\Program Files\curl\bin\curl.exe`.
- **PRTG Network Monitor**: For sensor integration.
- **NSX Manager**: Access to the NSX API.
- **Credentials**: Provide NSX Manager credentials via the `-Credential` parameter or set the environment variables `prtg_windowsuser` and `prtg_windowspassword`.

## Usage

1. **Clone or Download the Repository**

2. **Configure Credentials**

   The script supports two methods to supply credentials:   
   - **Environment Variables**: Set `prtg_windowsuser` and `prtg_windowspassword` in your environment.
   - **Parameter**: Supply a `PSCredential` using the `-Credential` parameter.
   
3. **Run the Script**

   Example usage:
   
   ```powershell
   .\Get-NSXAlarms.ps1 -ComputerName nsx-manager.example.com -Credential (Get-Credential)
   ```
   
4. **Integrate with PRTG**

   Configure a PRTG custom sensor to run this script. The sensor will display channels for "Red Alarms", "Yellow Alarms", and "Total Alarms" along with an explanatory message.

## Customization

- **Thresholds**: Modify the `-critThreshold` and `-warnThreshold` parameters as needed.
- **Curl Path**: If curl is located elsewhere, update the `$curlPath` variable in the script.

## Contributing

Contributions, feature suggestions, and bug reports are welcome. Feel free to [submit an issue](https://github.com/akbarraen/Custom-PRTG-Sensor-Scripts/issues) or create a pull request with your improvements.

## License

This project is licensed under the [MIT License](https://github.com/akbarraen/Custom-PRTG-Sensor-Scripts/blob/main/LICENSE).

---

*Happy monitoring!*
