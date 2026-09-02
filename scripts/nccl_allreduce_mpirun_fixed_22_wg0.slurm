#!/bin/bash
#SBATCH --job-name=nccl_true_split
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_split.%j.out

set -e

# 1. Environment
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# 2. THE TRUE SPLIT CONFIGURATION
# -------------------------------------------------------------------
# A. CONTROL (Handshake) -> Force to eno1
export NCCL_BOOTSTRAP_IFNAME=eno1

# B. DATA (2GB Buffers) -> Force to wg0 by EXCLUDING eno1
# This forces the "Net" layer to only see the VPN.
export NCCL_NET_IFNAME=^eno1,lo,docker0

# C. PLUGIN BYPASS
# Stop the IBext plugin from hijacking the 10G card.
export NCCL_NET_PLUGIN=none
export NCCL_IB_DISABLE=1

# D. CLEANUP
# We UNSET these to prevent them from overriding our split logic.
unset NCCL_NET
unset NCCL_SOCKET_IFNAME

export NCCL_DEBUG=INFO
# -------------------------------------------------------------------

NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

echo "Final Split Attempt: Bootstrap=eno1, Data=wg0 (eno1 excluded from Net)"

# 4. mpirun
# MPI coordinates via wg0 (Head Node compatibility)
# NCCL uses the variables passed via -x
mpirun -np $NUM_RANKS \
  -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include wg0 \
  --mca oob_tcp_if_include wg0 \
  -x NCCL_DEBUG=INFO \
  -x NCCL_BOOTSTRAP_IFNAME=eno1 \
  -x NCCL_NET_IFNAME=^eno1,lo,docker0 \
  -x NCCL_NET_PLUGIN=none \
  -x NCCL_IB_DISABLE=1 \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M -e 2G -f 1.1 -g 1 -n 100 -w 20
