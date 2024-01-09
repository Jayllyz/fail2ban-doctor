# Fail2ban Doctor

[![Super-Linter](https://github.com/jayllyz/fail2ban-doctor/actions/workflows/ci.yml/badge.svg)](https://github.com/marketplace/actions/super-linter)

This script is designed to manage fail2ban for SSH security and analyze authentication logs on a Linux system to provide insights into failed login attempts, IP addresses, and more.

## Features

- **Check Failed Login Attempts**: View the number of failed login attempts.
- **Failed Attempts by User**: Analyze failed login attempts by user and their occurrences.
- **Top Login Attempts**: Display top failed login attempts.
- **Failed Attempts by IP**: Check failed login attempts by IP address.
- **View fail2ban Status**: Check the status of fail2ban for SSH.
- **Disable SSH Root Login**: Disable root login via SSH for enhanced security.
- **Top Countries from IP Addresses**: Determine top countries based on IP addresses in the logs. (geoiplookup required)

> I have a lot of ideas for this script, expect more features soon.

## Usage

> [!NOTE]
> Root access is required for full access to logs and SSH configuration.
> The script require `geoiplookup` and `fail2ban`. If not present, it offers to install them.

The script has been tested on Ubuntu 23.10 x86_64 only for now.

```bash
curl -s https://raw.githubusercontent.com/jayllyz/fail2ban-doctor/main/doctor.sh | sudo bash
```
