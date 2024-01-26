# Fail2ban Doctor

[![Super-Linter](https://github.com/Jayllyz/fail2ban-doctor/actions/workflows/ci.yml/badge.svg)](https://github.com/marketplace/actions/super-linter)

This script is designed to manage fail2ban for SSH security and analyze authentication logs on a Linux system to provide insights into failed login attempts, IP addresses, and more.

## Features

- **Check Failed Login Attempts**: View the number of failed login attempts.
- **Top Login Attempts**: Display top usernames of failed login attempts.
- **Failed Attempts by IP**: Check failed login attempts by IP address.
- **View fail2ban Status**: Check the status of fail2ban for SSH.
- **Disable SSH Root Login**: Disable root login via SSH for enhanced security.
- **Top Countries**: Determine top countries based on banned IP addresses. (GeoIP Lookup)
- **Blackhole blacklist**: Use [blackhole](https://ip.blackhole.monster/blackhole-30days) to create a huge list of bad IP addresses to ban.
- **Update blackhole blacklist**: Update the blackhole blacklist every 30 days using cron.

> I have a lot of ideas for this script, expect more features soon.

## Usage

> [!NOTE]
> Root access is required for full access to logs and SSH configuration.
> The script require `geoiplookup` and `fail2ban`. If not present, it offers to install them.

The script has been tested on Ubuntu 23.10 x86_64 only for now.

```bash
curl -s https://raw.githubusercontent.com/jayllyz/fail2ban-doctor/main/doctor.sh | sudo bash
```

## Screenshots

<img src="https://raw.githubusercontent.com/jayllyz/fail2ban-doctor/main/assets/countries.png" alt="countries" height="500" width="400" />
