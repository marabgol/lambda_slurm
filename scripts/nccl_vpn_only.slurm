#!/bin/bash
#SBATCH --job-name=nccl_vpn_only
#SBATCH --partition=main
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --time=01:00:00
#SBATCH --chdir=/lambda/nfs/AIML/home/%u
#SBATCH --output=/lambda/nfs/AIML/home/%u/nccl_vpn_only.%j.out
#SBATCH --error=/lambda/nfs/AIML/home/%u/nccl_vpn_only.%j.err

set -e

echo "=========================================="
echo "NCCL Test - VPN ONLY (No InfiniBand)"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Nodes: $SLURM_JOB_NODELIST"
echo "Start time: $(date)"
echo ""

# MPI environment
export MPI=1
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# FORCE VPN-only by disabling IB plugin
export NCCL_NET_PLUGIN=none              # Disable RDMA plugin
export NCCL_IB_DISABLE=1                 # Disable InfiniBand
export NCCL_P2P_DISABLE=1                # Disable P2P (uses IB)
export NCCL_SOCKET_IFNAME=wg0            # Use VPN interface
export NCCL_NET_GDR_LEVEL=0              # Disable GPU Direct RDMA
export NCCL_MIN_CHUNK_SIZE=65536         # Smaller chunks for slower network
export NCCL_TIMEOUT=500                  # Increase timeout
export NCCL_DEBUG=INFO                   # Verbose logging

echo "=========================================="
echo "Environment Variables (VPN-ONLY mode):"
echo "=========================================="
echo "NCCL_NET_PLUGIN: $NCCL_NET_PLUGIN (disabled)"
echo "NCCL_IB_DISABLE: $NCCL_IB_DISABLE"
echo "NCCL_P2P_DISABLE: $NCCL_P2P_DISABLE"
echo "NCCL_SOCKET_IFNAME: $NCCL_SOCKET_IFNAME"
echo ""

echo "=========================================="
echo "Node Information:"
echo "=========================================="
echo "Hostname: $(hostname)"
echo "WireGuard IP: $(ip addr show wg0 | grep 'inet ' | awk '{print $2}')"
echo "InfiniBand (should NOT be used): $(ibstat 2>/dev/null | grep State || echo 'N/A')"
echo ""

echo "=========================================="
echo "GPU Status:"
echo "=========================================="
nvidia-smi
echo ""

echo "=========================================="
echo "Running NCCL Test - VPN ONLY:"
echo "=========================================="
echo "Expected bandwidth: ~0.1-0.12 GB/s (1 Gbps VPN limit)"
echo ""

# Run NCCL test - Should use VPN only
mpirun -np 2 --bind-to none -H node-01:1,node-02:1 --mca btl_tcp_if_include wg0 --mca oob_tcp_if_include wg0 -x NCCL_NET_PLUGIN -x NCCL_IB_DISABLE -x NCCL_P2P_DISABLE -x NCCL_SOCKET_IFNAME -x NCCL_NET_GDR_LEVEL -x NCCL_MIN_CHUNK_SIZE -x NCCL_TIMEOUT -x NCCL_DEBUG /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf -b 8M -e 128M -f 2 -g 1

echo ""
echo "=========================================="
echo "Test Complete!"
echo "End time: $(date)"
echo ""
echo "If bandwidth is ~0.1 GB/s, VPN was used."
echo "If bandwidth is 100+ GB/s, InfiniBand was used."
echo "=========================================="
