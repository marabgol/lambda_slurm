#!/bin/bash
#SBATCH --job-name=nccl_true_split
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_split.%j.out

set -e

# 1. Paths
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# 2. THE TRUE SPLIT CONFIGURATION
# -------------------------------------------------------------------
# Force Bootstrap (Control) to use eno1
export NCCL_SOCKET_IFNAME=eno1

# Force Data Transfer to use wg0
export NCCL_NET_IFNAME=wg0

# NEW: Disable the external RoCE plugin to stop it from hijacking data
export NCCL_NET_PLUGIN=none

# Ensure RDMA/InfiniBand logic is completely off
export NCCL_IB_DISABLE=1
export NCCL_NET=Socket
export NCCL_DEBUG=INFO
# -------------------------------------------------------------------

# 3. Setup Ranks
NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

echo "Job $SLURM_JOB_ID: Forcing split with Plugin Disable"

# 4. mpirun
# Pass all specific variables to the worker nodes
mpirun -np $NUM_RANKS \
  -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include eno1 \
  --mca oob_tcp_if_include eno1 \
  -x NCCL_DEBUG=INFO \
  -x NCCL_SOCKET_IFNAME=eno1 \
  -x NCCL_NET_IFNAME=wg0 \
  -x NCCL_NET_PLUGIN=none \
  -x NCCL_IB_DISABLE=1 \
  -x NCCL_NET=Socket \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M -e 2G -f 1.1 -g 1 -n 100 -w 20
