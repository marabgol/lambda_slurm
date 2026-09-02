#!/bin/bash
# Quick fix for slurmctld crash on head node

echo "=========================================="
echo "Quick Fix: slurmctld crash"
echo "=========================================="
echo ""

# Check if running on head node
if [ ! -f /usr/sbin/slurmctld ]; then
    echo "ERROR: This doesn't appear to be the head node"
    echo "Run this script on the head node only"
    exit 1
fi

# Stop slurmctld
echo "1. Stopping slurmctld..."
sudo systemctl stop slurmctld

# Create systemd override directory
echo "2. Creating systemd override..."
sudo mkdir -p /etc/systemd/system/slurmctld.service.d

# Create override to run as root
sudo tee /etc/systemd/system/slurmctld.service.d/override.conf > /dev/null << 'EOF'
[Service]
Type=forking
User=root
Group=root
ExecStart=
ExecStart=/usr/sbin/slurmctld $SLURMCTLD_OPTIONS
EOF

echo "   ✓ slurmctld will now run as root"

# Create script directory
echo "3. Creating script directory..."
sudo mkdir -p /var/spool/slurm/script
sudo chown slurm:slurm /var/spool/slurm/script
sudo chmod 755 /var/spool/slurm/script
echo "   ✓ Created /var/spool/slurm/script"

# Fix permissions
echo "4. Fixing permissions..."
sudo chown -R slurm:slurm /var/spool/slurm/ctld /var/log/slurm 2>/dev/null || true
echo "   ✓ Permissions fixed"

# Reload systemd
echo "5. Reloading systemd..."
sudo systemctl daemon-reload

# Start slurmctld
echo "6. Starting slurmctld..."
sudo systemctl start slurmctld

# Wait a moment
sleep 3

# Check status
echo ""
echo "=========================================="
echo "Status Check:"
echo "=========================================="

if sudo systemctl is-active slurmctld > /dev/null 2>&1; then
    echo "✓ slurmctld is RUNNING"
    echo ""
    echo "Recent logs:"
    sudo tail -20 /var/log/slurm/slurmctld.log | grep -v "debug"
    echo ""
    echo "Cluster status:"
    sinfo
else
    echo "✗ slurmctld FAILED to start"
    echo ""
    echo "Error logs:"
    sudo tail -30 /var/log/slurm/slurmctld.log | grep -E "fatal|error|Error"
    echo ""
    echo "Full status:"
    sudo systemctl status slurmctld
fi

echo ""
echo "=========================================="
echo "Next steps:"
echo "  - Check workers: ssh node-01 'systemctl status slurmd'"
echo "  - Test munge: munge -n | ssh node-01 unmunge"
echo "  - Submit job: sbatch --wrap='hostname && date'"
echo "=========================================="
