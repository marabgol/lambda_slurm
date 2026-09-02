#!/bin/bash

# Configuration
DEVICE="mlx5_0"
PORT="1"
INTERVAL=1  # Seconds between checks

echo "Monitoring $DEVICE port $PORT every $INTERVAL second(s)..."
echo "--------------------------------------------------------"
printf "%-10s | %-15s | %-15s\n" "Direction" "Speed (MB/s)" "Speed (Gbps)"
echo "--------------------------------------------------------"

# Path to counters
TX_PATH="/sys/class/infiniband/$DEVICE/ports/$PORT/counters/port_xmit_data"
RX_PATH="/sys/class/infiniband/$DEVICE/ports/$PORT/counters/port_rcv_data"

while true; do
    # Read initial counters
    TX1=$(cat $TX_PATH)
    RX1=$(cat $RX_PATH)
    
    sleep $INTERVAL
    
    # Read counters after interval
    TX2=$(cat $TX_PATH)
    RX2=$(cat $RX_PATH)
    
    # Calculate deltas
    # Note: Mellanox counters count in 4-byte words (quad-bytes)
    TX_DELTA=$(( (TX2 - TX1) * 4 ))
    RX_DELTA=$(( (RX2 - RX1) * 4 ))
    
    # Convert to MB/s
    TX_MB=$(echo "scale=2; $TX_DELTA / 1024 / 1024 / $INTERVAL" | bc)
    RX_MB=$(echo "scale=2; $RX_DELTA / 1024 / 1024 / $INTERVAL" | bc)
    
    # Convert to Gbps (Bits per second)
    TX_GBPS=$(echo "scale=2; ($TX_DELTA * 8) / 1000 / 1000 / 1000 / $INTERVAL" | bc)
    RX_GBPS=$(echo "scale=2; ($RX_DELTA * 8) / 1000 / 1000 / 1000 / $INTERVAL" | bc)
    
    # Move cursor up 2 lines to refresh the display
    printf "\r%-10s | %-15s | %-15s\n" "SEND" "$TX_MB MB/s" "$TX_GBPS Gbps"
    printf "%-10s | %-15s | %-15s\033[A" "RECV" "$RX_MB MB/s" "$RX_GBPS Gbps"
done
