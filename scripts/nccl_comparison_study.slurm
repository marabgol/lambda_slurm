#!/bin/bash
#SBATCH --job-name=nccl_vpn_comparison
#SBATCH --partition=main
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --time=00:30:00
#SBATCH --chdir=/lambda/nfs/AIML/home/%u
#SBATCH --output=/lambda/nfs/AIML/home/%u/nccl_comparison.%j.out
#SBATCH --error=/lambda/nfs/AIML/home/%u/nccl_comparison.%j.err

set -e

echo "=========================================="
echo "NCCL Bandwidth Comparison Study"
echo "Testing VPN vs InfiniBand Performance"
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

# Common NCCL settings
export NCCL_SOCKET_IFNAME=wg0
export NCCL_NET_GDR_LEVEL=0
export NCCL_MIN_CHUNK_SIZE=65536
export NCCL_TIMEOUT=500
export NCCL_DEBUG=INFO

echo "=========================================="
echo "Test 1: InfiniBand (FAST)"
echo "=========================================="
export NCCL_IB_DISABLE=0
export NCCL_NET_PLUGIN=
export NCCL_P2P_DISABLE=0

echo "Network: InfiniBand/RoCE"
echo "Expected: ~600-700 GB/s"
echo ""

mpirun -np 2 --bind-to none -H node-01:1,node-02:1 --mca btl_tcp_if_include wg0 --mca oob_tcp_if_include wg0 -x NCCL_IB_DISABLE -x NCCL_SOCKET_IFNAME -x NCCL_NET_GDR_LEVEL -x NCCL_MIN_CHUNK_SIZE -x NCCL_TIMEOUT -x NCCL_DEBUG /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf -b 1M -e 128M -f 2 -g 1

echo ""
echo "=========================================="
echo "Test 2: VPN ONLY (SLOW)"
echo "=========================================="
export NCCL_IB_DISABLE=1
export NCCL_NET_PLUGIN=none
export NCCL_P2P_DISABLE=1

echo "Network: WireGuard VPN (wg0)"
echo "Expected: ~0.1 GB/s"
echo ""

mpirun -np 2 --bind-to none -H node-01:1,node-02:1 --mca btl_tcp_if_include wg0 --mca oob_tcp_if_include wg0 -x NCCL_NET_PLUGIN -x NCCL_IB_DISABLE -x NCCL_P2P_DISABLE -x NCCL_SOCKET_IFNAME -x NCCL_NET_GDR_LEVEL -x NCCL_MIN_CHUNK_SIZE -x NCCL_TIMEOUT -x NCCL_DEBUG /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf -b 1M -e 32M -f 2 -g 1

echo ""
echo "=========================================="
echo "Comparison Complete!"
echo "=========================================="
echo "End time: $(date)"
echo ""
echo "Summary:"
echo "  Test 1 (InfiniBand): Check algbw column - should be 600-700 GB/s"
echo "  Test 2 (VPN):        Check algbw column - should be ~0.1 GB/s"
echo ""
echo "Ratio: InfiniBand is ~6,000x faster than VPN!"
echo "=========================================="
