#!/bin/bash
#SBATCH --job-name=nccl_vpn_alt
#SBATCH --partition=main
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --time=01:00:00
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_vpn_alt.%j.out
#SBATCH --error=/lambda/nfs/AIML/home/majid/nccl_vpn_alt.%j.err

set -e

cd /lambda/nfs/AIML/home/majid

echo "=========================================="
echo "NCCL Multi-Node Test - VPN ONLY (mpirun)"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Nodes: $SLURM_JOB_NODELIST"
echo "Tasks: $SLURM_NTASKS"
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
echo "Environment:"
echo "=========================================="
echo "SLURM_JOB_NODELIST: $SLURM_JOB_NODELIST"
echo "SLURM_NTASKS: $SLURM_NTASKS"
echo "SLURM_NNODES: $SLURM_NNODES"
echo ""

echo "=========================================="
echo "CRITICAL Check - Must show:"
echo "  nRanks 2, nNodes 2"
echo "=========================================="
echo ""

# Use mpirun with explicit node list and task count
# Let MPI coordinate with Slurm
mpirun \
  --bind-to none \
  --map-by ppr:1:node \
  -x NCCL_NET_PLUGIN \
  -x NCCL_IB_DISABLE \
  -x NCCL_P2P_DISABLE \
  -x NCCL_SOCKET_IFNAME \
  -x NCCL_NET_GDR_LEVEL \
  -x NCCL_DEBUG \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf -b 8M -e 64M -f 2 -g 1

echo ""
echo "=========================================="
echo "Test Complete! Check above for:"
echo "  - nRanks 2, nNodes 2 ✓"
echo "  - Bandwidth ~0.1 GB/s ✓"
echo "=========================================="
