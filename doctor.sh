#!/bin/bash

VERSION="0.1.0"
RESET='\033[0m'
WARNING='\033[0;33m'
INFO='\033[0;36m'
ERROR='\033[0;31m'
SUCCESS='\033[0;32m'
LOGFILE='/tmp/tempDoctor/auth.log'
FAIL2BAN_LOGFILE='/var/log/fail2ban.log'

function print_ascii() {
    echo -e "${INFO}  _____     _ _ ____  ____                    ____             _             "
    echo -e "${INFO} |  ___|_ _(_) |___ \| __ )  __ _ _ __       |  _ \  ___   ___| |_ ___  _ __ "
    echo -e "${INFO} | |_ / _\` | | | __) |  _ \ / _\` | '_ \ _____| | | |/ _ \ / __| __/ _ \| '__|"
    echo -e "${INFO} |  _| (_| | | |/ __/| |_) | (_| | | | |_____| |_| | (_) | (__| || (_) | |   "
    echo -e "${INFO} |_|  \__,_|_|_|_____|____/ \__,_|_| |_|     |____/ \___/ \___|\__\___/|_|   "
    echo -e "${INFO}                                                                              "
    echo -e "${INFO}Version: ${VERSION}${RESET}"
}

function check_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "Please run as root"
        exit
    fi
}

function requierements() {
    if ! command -v geoiplookup &>/dev/null; then
        echo -e "${WARNING}geoiplookup is not installed${RESET}"
        read -r -p "Do you want to install geoiplookup? [y/N] " response
        if [[ "${response}" = "y" || "${response}" = "Y" ]]; then
            apt install geoip-bin -y
        fi
    fi
    if ! command -v fail2ban-client &>/dev/null; then
        echo -e "${WARNING}fail2ban is not installed${RESET}"
        read -r -p "Do you want to install fail2ban? [y/N] " response
        if [[ "${response}" = "y" || "${response}" = "Y" ]]; then
            install_fail2ban
        fi
    fi
}

function install_fail2ban() {
    echo -e "${INFO}Installing fail2ban...${RESET}"
    apt install fail2ban -y
    systemctl enable fail2ban
    systemctl start fail2ban
}

function merge_logs() {
    mkdir -p /tmp/tempDoctor
    cp /var/log/auth.log* /tmp/tempDoctor
    rm -rf /tmp/tempDoctor/*.gz
    cat /tmp/tempDoctor/auth.log* >>"${LOGFILE}"
}

function remove_logs() {
    rm -rf /tmp/tempDoctor
}

function press_enter() {
    echo ""
    echo -n "Press Enter to continue"
    read -r
    clear
}

function menu() {
    clear
    echo -e "${INFO}Select an option:${RESET}"
    echo -e "${INFO}1) Check the number of failed login attempts${RESET}"
    echo -e "${INFO}2) Check the top user login attempts${RESET}"
    echo -e "${INFO}3) Check the number of failed login attempts by IP${RESET}"
    echo -e "${INFO}4) View fail2ban sshd status${RESET}"
    echo -e "${INFO}5) Disable ssh root login${RESET}"
    echo -e "${INFO}6) Top countries from IP addresses${RESET}"
    echo -e "${INFO}7) Blackhole filter setup${RESET}"
    echo -e "${INFO}8) Exit${RESET}"
    read -r option
    case ${option} in
    1)
        check_attemps
        ;;
    2)
        read -r -p "How many? " top
        if [[ ! "${top}" =~ ^[0-9]+$ ]]; then
            top=10
        fi
        top_login_attempts "${top}"
        ;;
    3)
        check_attemps_by_ip
        ;;
    4)
        check_sshd_status
        ;;
    5)
        disable_ssh_root_login
        ;;
    6)
        read -r -p "How many? " top
        if [[ ! "${top}" =~ ^[0-9]+$ ]]; then
            top=10
        fi
        top_countries_from_ips_ban "${top}"
        ;;
    7)
        echo -e "${INFO}This will update the blackhole banlist, create a blackhole filter, add a blackhole jail and create a cron to update the banlist every month${RESET}"
        update_blackhole
        create_blackhole_filter
        add_blackhole_jail
        cron_blackhole
        ;;
    8)
        remove_logs
        exit
        ;;

    *)
        echo -e "${ERROR}Invalid option${RESET}"
        ;;
    esac
}

function check_attemps() {
    failed_login_attempts=$(grep -c 'Failed password for' "${LOGFILE}" || true)
    echo -e "${INFO}The number of failed login attempts is ${SUCCESS}${failed_login_attempts}${RESET}"
    press_enter
}

function top_login_attempts() {
    echo -e "${INFO}Checking the top $1 login attempts...${RESET}"
    top_login_attempts=$(grep 'Failed password for' "${LOGFILE}" | awk '{print $(NF-5)}' | sort | uniq -c | sort -nr | head -n "$1" || true)

    echo "---------------------------------------------"
    echo "| Login                      | Occurrences  |"
    echo "---------------------------------------------"
    while read -r line; do
        occ=$(echo "${line}" | awk '{print $1}')
        username=$(echo "${line}" | awk '{$1=""; print $0}' | xargs -0 || true)
        printf "| %-25s | %-12s |\n" "${username}" "${occ}"
    done <<<"${top_login_attempts}"
    echo "---------------------------------------------"
    press_enter
}

function top_countries_from_ips_ban() {
    echo -e "${INFO}Checking the top $1 countries based on banned IPs...${RESET}"
    echo -e "${WARNING}Working... This may take a while, please be patient. (checking sshd jail only)${RESET}"

    # Take only lines from sshd jail
    sshd_log=$(grep "sshd" "${FAIL2BAN_LOGFILE}")
    ips=$(echo "${sshd_log}" | grep -E "Ban .*" | awk '{print $NF}' | sort | uniq || true)

    declare -A countries_occurrences
    countries_occurrences=()

    while read -r line; do

        ip=$(echo "${line}" | tr -d '[:space:]')
        if [[ "${ip}" =~ ":" ]]; then
            continue
        fi

        country=$(geoiplookup "${ip}" | cut -d ',' -f2 || true)

        if [[ -z "${countries_occurrences[${country}]}" ]]; then
            countries_occurrences[${country}]=1
        else
            countries_occurrences[${country}]=$((countries_occurrences[${country}] + 1))
        fi
    done <<<"${ips}"

    sorted_countries_occurrences=$(for country in "${!countries_occurrences[@]}"; do
        echo "${countries_occurrences[${country}]} ${country}"
    done | sort -rn || true)

    echo "--------------------------------------------"
    echo "| Country                    | Occurrences |"
    echo "--------------------------------------------"
    while read -r line || true; do
        occ=$(echo "${line}" | awk '{print $1}' || true)
        country=$(echo "${line}" | awk '{$1=""; print $0}' | xargs -0 || true)
        printf "| %-25s | %-12s |\n" "${country}" "${occ}"
    done <<<"${sorted_countries_occurrences}" | head -n "$1"
    echo "--------------------------------------------"
    press_enter
}

function check_attemps_by_ip() {
    echo -e "${INFO}Checking the number of failed login attempts by IP...${RESET}"
    ip_attempts=$(grep 'Failed password for invalid user' "${LOGFILE}" | awk '{print $(NF-3)}' | sort | uniq -c || true)

    echo "--------------------------------------------"
    echo "| IP                         | Occurrences |"
    echo "--------------------------------------------"
    while read -r line; do
        occ=$(echo "${line}" | awk '{print $1}')
        ip=$(echo "${line}" | awk '{$1=""; print $0}' | xargs -0 || true)
        printf "| %-25s | %-12s |\n" "${ip}" "${occ}"
    done <<<"${ip_attempts}"
    echo "--------------------------------------------"
    press_enter
}

function check_sshd_status() {
    fail2ban-client status sshd
    press_enter
}

function disable_ssh_root_login() {
    echo -e "${WARNING}Are you sure you want to disable root login?${RESET}"
    echo -e "${WARNING}If you disable root login, you will not be able to login as root anymore${RESET}"
    read -r -p "Continue? [y/N] " response
    if [[ ! "${response}" =~ ^([yY])+$ ]]; then
        return
    fi
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
    systemctl restart sshd
    echo -e "${INFO}Root login disabled${RESET}"
    press_enter
}

function update_blackhole() {
    curl --compressed https://ip.blackhole.monster/blackhole-30days >/etc/fail2ban/blackhole.txt 2>/dev/null
    echo -e "${INFO}Blackhole banlist updated in /etc/fail2ban/blackhole.txt${RESET}"
}

function create_blackhole_filter() {
    if [[ -f /etc/fail2ban/filter.d/blackhole.conf ]]; then
        echo -e "${WARNING}Blackhole filter already exists${RESET}"
        read -r -p "Do you want to overwrite it? [y/N] " response
        if [[ ! "${response}" =~ ^([yY])+$ ]]; then
            return
        fi
    fi

    cat <<EOF >/etc/fail2ban/filter.d/blackhole.conf
    [Definition]
    failregex = ^<HOST>$
    ignoreregex =
    port = all

EOF
    echo -e "${INFO}Blackhole filter created in /etc/fail2ban/filter.d/blackhole.conf${RESET}"
}

function add_blackhole_jail() {
    if [[ -f /etc/fail2ban/jail.local ]]; then
        if grep -q "\[blackhole\]" /etc/fail2ban/jail.local; then
            return
        fi
    fi

    cat <<EOF >>/etc/fail2ban/jail.local
              
    [blackhole]
    enabled = true
    filter = blackhole
    logpath = /etc/fail2ban/blackhole.txt
    maxretry = 1
    banaction = iptables-allports
    bantime = 30d

EOF
    echo -e "${INFO}Blackhole jail added${RESET}"
    systemctl reload fail2ban
}

function cron_blackhole() {
    if [[ -f /etc/cron.monthly/blackhole ]]; then
        echo -e "${WARNING}Blackhole cron already exists${RESET}"
        read -r -p "Do you want to overwrite it? [y/N] " response
        if [[ ! "${response}" =~ ^([yY])+$ ]]; then
            return
        fi
    fi

    cat <<EOF >/etc/cron.monthly/blackhole
    #!/bin/bash
    curl --compressed https://ip.blackhole.monster/blackhole-30days >/etc/fail2ban/blackhole.txt 2>/dev/null
    systemctl reload fail2ban

EOF
    echo -e "${INFO}Blackhole cron created in /etc/cron.monthly/blackhole${RESET}"
    press_enter
}

function main() {
    check_root
    requierements
    merge_logs
    print_ascii
    press_enter
    while true; do
        clear
        menu
    done
}

main
