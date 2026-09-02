#!/bin/bash
#SBATCH --job-name=nccl_split_final
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
# A. LOCK BOOTSTRAP TO ENO1 (Control Plane)
# In NCCL 2.26, this variable is the highest priority for the handshake.
export NCCL_BOOTSTRAP_IFNAME=eno1

# B. LOCK DATA TO WG0 (Data Plane)
# We use SOCKET_IFNAME because we are forcing 'Socket' mode below.
export NCCL_SOCKET_IFNAME=wg0

# C. BYPASS THE PLUGIN
# This forces NCCL to ignore the Mellanox IBext RDMA plugin and use TCP.
export NCCL_NET=Socket
export NCCL_IB_DISABLE=1

export NCCL_DEBUG=INFO
# -------------------------------------------------------------------

NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

echo "Head node compatibility via wg0. Compute split: Bootstrap=eno1, Data=wg0"

# 4. mpirun
# MPI uses wg0 (bridge between head and compute)
# NCCL uses the variables passed via -x
mpirun -np $NUM_RANKS \
  -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include wg0 \
  --mca oob_tcp_if_include wg0 \
  -x NCCL_DEBUG=INFO \
  -x NCCL_BOOTSTRAP_IFNAME=eno1 \
  -x NCCL_SOCKET_IFNAME=wg0 \
  -x NCCL_NET=Socket \
  -x NCCL_IB_DISABLE=1 \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M -e 2G -f 1.1 -g 1 -n 100 -w 20
