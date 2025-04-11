# Custom PRTG Sensor Scripts

Welcome to the **Custom PRTG Sensor Scripts** repository. This project provides a collection of PowerShell-based custom sensor scripts for [PRTG Network Monitor](https://www.paessler.com/prtg) that are tailored to monitor health and performance across various hyper-converged environments including Nutanix, HPE SimpliVity, and (in future) VMware.

<!-- SENSOR LIST START -->
Sensor List:
- **[.git:](./.git)**
- **[Nutanix:](./Nutanix)**
  - **[Nutanix](./Nutanix/)**
    - *PRTG_NutanixAlertsAndHealthSensor.ps1*
- **[SimpliVity:](./SimpliVity)**
  - **[SimpliVity](./SimpliVity/)**
    - *PRTG-Simplivity-Health.ps1*

<!-- SENSOR LIST END -->
---
## Repository Structure
<!-- REPO STRUCTURE START -->
```
Custom-PRTG-Sensor-Scripts/
├── .git/
│   ├── hooks/
│   ├── info/
│   ├── logs/
│   ├── objects/
│   ├── refs/
├── Nutanix/
├── SimpliVity/
```

<!-- REPO STRUCTURE END -->

## Getting Started

1. **Choose Your Environment:**  
   Navigate to the folder corresponding to your target technology (e.g., `Nutanix`, `SimpliVity`).

2. **Review Environment Documentation:**  
   Each folder has a README that provides detailed instructions on prerequisites, configuration, and usage.

3. **Integrate with PRTG:**  
   Configure your PRTG Network Monitor to use these scripts as custom sensors. Follow the guidelines provided in each environment's documentation.
---
## Contributing
Your contributions are vital to the success of this project. Whether it’s new sensor scripts, enhancements, or improving the automation of our documentation:
- Please open an issue with your ideas or bugs.
- Feel free to submit a pull request with your improvements.

---
## License
This project is licensed under the [LICENSE](./LICENSE) license.

---

## Support
If you have any questions, issues, or feedback regarding the sensor scripts or documentation, please open an issue in this repository.

---

This README is designed to evolve with the project. As new sensor scripts for additional technologies are added, the document will be maintained either manually or through automation tools to ensure it consistently provides an up-to-date overview of capabilities. Suggestions for automating this process are welcome.

---
