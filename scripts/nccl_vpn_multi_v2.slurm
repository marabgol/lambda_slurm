#!/bin/bash
#SBATCH --job-name=nccl_vpn_multinode
#SBATCH --partition=main
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --time=01:00:00
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_vpn_multi.%j.out
#SBATCH --error=/lambda/nfs/AIML/home/majid/nccl_vpn_multi.%j.err

set -e

# Change to shared NFS directory
cd /lambda/nfs/AIML/home/majid

echo "=========================================="
echo "NCCL Multi-Node Test - VPN ONLY"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Nodes: $SLURM_JOB_NODELIST"
echo "Tasks: $SLURM_NTASKS"
echo "Working dir: $(pwd)"
echo "Start time: $(date)"
echo ""

# MPI environment
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# FORCE VPN-only communication
export NCCL_NET_PLUGIN=none
export NCCL_IB_DISABLE=1
export NCCL_P2P_DISABLE=1
export NCCL_SOCKET_IFNAME=wg0
export NCCL_NET_GDR_LEVEL=0
export NCCL_DEBUG=INFO

echo "=========================================="
echo "CRITICAL: This test MUST show:"
echo "  nRanks 2 (not 1!)"
echo "  nNodes 2 (not 1!)"
echo "If it shows nRanks 1, the test is broken!"
echo "=========================================="
echo ""

# Use srun with pmi2 (more compatible than pmix)
srun --mpi=pmi2 /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf -b 8M -e 64M -f 2 -g 1

echo ""
echo "=========================================="
echo "Test Complete!"
echo "=========================================="
echo ""
echo "VERIFY OUTPUT ABOVE:"
echo "  - Should show: nRanks 2, nNodes 2"
echo "  - If nRanks 1: test failed, no inter-node comm"
echo "  - If bandwidth ~0.1 GB/s: VPN was used ✓"
echo "  - If bandwidth 500+ GB/s: something wrong!"
echo "=========================================="
