#!/bin/bash

# NetGO - Network IP Scanner for Windows Bash
# Author - Khenjie M.

# Function to display help
display_help() {
    echo "NetGO - Network IP Scanner"
    echo "Usage: ./netgo.sh [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -f, --fast     Perform a fast scan (only ping)"
    echo "  -v, --verbose  Show detailed output"
    echo ""
    echo "Example:"
    echo "  ./netgo.sh      # Standard scan"
    echo "  ./netgo.sh -f   # Fast scan"
}

# Function to get the local network IP range
get_network_range() {
    # Try different methods to get the IP address
    local ip_cmd=""
    
    # Check for ip command (WSL)
    if command -v ip &> /dev/null; then
        ip_cmd="ip addr"
    # Check for ifconfig
    elif command -v ifconfig &> /dev/null; then
        ip_cmd="ifconfig"
    # Check for Windows ipconfig
    elif command -v ipconfig &> /dev/null; then
        ip_addr=$(ipconfig | grep -i "IPv4 Address" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        echo "$ip_addr"
        return
    else
        echo "Could not determine IP address. No suitable command found." >&2
        exit 1
    fi

    # Extract IP address
    local ip_addr=$($ip_cmd | grep -oE 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -oE '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
    echo "$ip_addr"
}

# Function to perform the scan
scan_network() {
    local network_range="$1"
    local fast_scan="$2"
    local verbose="$3"
    
    echo "Scanning network range: $network_range.0/24"
    echo "-----------------------------------------"
    
    for ip in {1..254}; do
        current_ip="$network_range.$ip"
        
        if [ "$fast_scan" = true ]; then
            # Fast scan with just ping
            if ping -n 1 -w 500 "$current_ip" &> /dev/null; then
                echo "Host $current_ip is UP"
            fi
        else
            # More thorough scan
            if ping -n 1 -w 500 "$current_ip" &> /dev/null; then
                echo "Host $current_ip is UP"
                
                if [ "$verbose" = true ]; then
                    # Try to get hostname (works on Windows)
                    hostname=$(nslookup "$current_ip" 2>/dev/null | grep "Name" | awk '{print $2}')
                    if [ -n "$hostname" ]; then
                        echo "  Hostname: $hostname"
                    fi
                    
                    # Try to get MAC address (may not work on all Windows systems)
                    if command -v arp &> /dev/null; then
                        # Populate ARP cache
                        ping -n 2 -w 1000 "$current_ip" &> /dev/null
                        mac=$(arp -a "$current_ip" | grep -oE '([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})' | head -1)
                        if [ -n "$mac" ]; then
                            echo "  MAC Address: $mac"
                        fi
                    fi
                fi
            fi
        fi
    done
}

# Main script
main() {
    local fast_scan=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                display_help
                exit 0
                ;;
            -f|--fast)
                fast_scan=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                display_help
                exit 1
                ;;
        esac
    done
    
    echo "NetGO - Network IP Scanner"
    echo "-------------------------"
    
    # Get local IP and determine network range
    local_ip=$(get_network_range)
    if [ -z "$local_ip" ]; then
        echo "ERROR: Could not determine local IP address." >&2
        exit 1
    fi
    
    network_range=$(echo "$local_ip" | cut -d'.' -f1-3)
    echo "Detected local IP: $local_ip"
    echo "Network range: $network_range.0/24"
    
    # Perform the scan
    scan_network "$network_range" "$fast_scan" "$verbose"
    
    echo ""
    echo "Scan completed."
}

# Run main function with all arguments
main "$@"