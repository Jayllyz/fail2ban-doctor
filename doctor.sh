#!/bin/bash

VERSION="1.0.0"
RESET='\033[0m'
WARNING='\033[0;33m'
INFO='\033[0;36m'
ERROR='\033[0;31m'
SUCCESS='\033[0;32m'
LOGFILE="/var/log/auth.log"
FAil2BAN_LOGFILE="/var/log/fail2ban.log"

function print_ascii() {
    echo -e "${INFO}  _____     _ _ ____  ____                    ____             _             "
    echo -e "${INFO} |  ___|_ _(_) |___ \| __ )  __ _ _ __       |  _ \  ___   ___| |_ ___  _ __ "
    echo -e "${INFO} | |_ / _\` | | | __) |  _ \ / _\` | '_ \ _____| | | |/ _ \ / __| __/ _ \| '__|"
    echo -e "${INFO} |  _| (_| | | |/ __/| |_) | (_| | | | |_____| |_| | (_) | (__| || (_) | |   "
    echo -e "${INFO} |_|  \__,_|_|_|_____|____/ \__,_|_| |_|     |____/ \___/ \___|\__\___/|_|   "
    echo -e "${INFO}                                                                              "
    echo -e "${INFO}Version: ${VERSION}${RESET}"
}

# check if the user is root
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
    echo -e "${INFO}2) Check the number of failed login attempts by user${RESET}"
    echo -e "${INFO}3) Check the top login attempts${RESET}"
    echo -e "${INFO}4) Check the number of failed login attempts by IP${RESET}"
    echo -e "${INFO}5) View fail2ban sshd status${RESET}"
    echo -e "${INFO}6) Disable ssh root login${RESET}"
    echo -e "${INFO}7) Top countries from IP addresses${RESET}"
    echo -e "${INFO}8) Exit${RESET}"
    read -r option
    case ${option} in
    1)
        check_attemps
        ;;
    2)
        check_attemps_by_user
        ;;
    3)
        read -r -p "How many? " top
        if [[ ! "${top}" =~ ^[0-9]+$ ]]; then
            top=10
        fi
        top_login_attempts "${top}"
        ;;
    4)
        check_attemps_by_ip
        ;;
    5)
        check_fail2ban_status
        ;;
    6)
        disable_ssh_root_login
        ;;
    7)
        read -r -p "How many? " top
        if [[ ! "${top}" =~ ^[0-9]+$ ]]; then
            top=10
        fi
        top_countries_from_ips_ban "${top}"
        ;;
    8)
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

function check_attemps_by_user() {
    echo -e "${INFO}Checking the number of failed login attempts by user...${RESET}"
    user_attempts=$(grep 'Failed password for invalid user' "${LOGFILE}" | awk '{print $(NF-5)}' | sort | uniq -c || true)

    echo "---------------------------------------------"
    echo "| Login                      | Occurrences  |"
    echo "---------------------------------------------"
    while read -r line; do
        occ=$(echo "${line}" | awk '{print $1}')
        username=$(echo "${line}" | awk '{$1=""; print $0}' | xargs -0 || true)
        printf "| %-25s | %-12s |\n" "${username}" "${occ}"
    done <<<"${user_attempts}"
    echo "---------------------------------------------"
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
    echo -e "${WARNING}Working... This may take a while, please be patient.${RESET}"

    ips=$(grep -Eo "Ban .*" "${FAil2BAN_LOGFILE}" | awk '{print $2}' | sort | uniq || true)

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

function check_fail2ban_status() {
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

function main() {
    check_root
    requierements
    print_ascii
    press_enter
    while true; do
        clear
        menu
    done
}

main
