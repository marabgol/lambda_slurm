#!/bin/bash
#SBATCH --job-name=nccl_vpn_test
#SBATCH --partition=main
#SBATCH --nodes=2                  # Number of nodes
#SBATCH --ntasks-per-node=1        # 1 process per node
#SBATCH --cpus-per-task=4          # Number of CPU cores per MPI rank
#SBATCH --gres=gpu:1               # 1 GPU per node (FIXED: was --gpus-per-node)
#SBATCH --time=01:00:00            # Job runtime (hh:mm:ss)
#SBATCH --output=/lambda/nfs/AIML/home/%u/nccl_test.%j.out
#SBATCH --error=/lambda/nfs/AIML/home/%u/nccl_test.%j.err

set -e  # Exit on error
set -x  # Print commands (for debugging)

echo "=========================================="
echo "NCCL Test - Multi-Node GPU Communication"
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

# NCCL environment for WireGuard VPN (FIXED!)
export NCCL_SOCKET_IFNAME=wg0       # Use WireGuard VPN interface (was eno1)
export NCCL_IB_DISABLE=1            # Disable InfiniBand
export NCCL_NET_GDR_LEVEL=0         # Disable GPU Direct RDMA
export NCCL_MIN_CHUNK_SIZE=65536    # Smaller chunks for slower network
export NCCL_TIMEOUT=500             # Increase timeout for slow network
export NCCL_DEBUG=INFO              # Verbose logging

echo "=========================================="
echo "Environment Variables:"
echo "=========================================="
echo "MPI_HOME: $MPI_HOME"
echo "NCCL_SOCKET_IFNAME: $NCCL_SOCKET_IFNAME"
echo "NCCL_DEBUG: $NCCL_DEBUG"
echo ""

echo "=========================================="
echo "Node Information:"
echo "=========================================="
echo "Hostname: $(hostname)"
echo "WireGuard IP: $(ip addr show wg0 | grep 'inet ' | awk '{print $2}')"
echo ""

echo "=========================================="
echo "GPU Status (before test):"
echo "=========================================="
nvidia-smi
echo ""

echo "=========================================="
echo "Running NCCL All-Reduce Test:"
echo "=========================================="
echo "Command: mpirun -np 2 -H node-01:1,node-02:1 ..."
echo ""

mpirun -np 2 --bind-to none \
-H node-01:1,node-02:1 \
--mca btl_tcp_if_include wg0 \
 --mca oob_tcp_if_include wg0 \
-x NCCL_SOCKET_IFNAME -x NCCL_IB_DISABLE -x \
NCCL_NET_GDR_LEVEL -x NCCL_MIN_CHUNK_SIZE -x \
#NCCL_TIMEOUT -x NCCL_DEBUG /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf -b 8M -e 2G -f 2 -g 1
NCCL_TIMEOUT -x NCCL_DEBUG /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf -b 8M -e 2G -f 2 -g 1 -n 100

echo ""
echo "=========================================="
echo "GPU Status (after test):"
echo "=========================================="
nvidia-smi
echo ""

echo "=========================================="
echo "Test Complete!"
echo "End time: $(date)"
echo "=========================================="
