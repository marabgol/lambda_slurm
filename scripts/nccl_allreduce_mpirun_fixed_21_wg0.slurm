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

# 2. THE TRUE ROLE-BASED SPLIT
# -------------------------------------------------------------------
# A. HANDSHAKE (Bootstrap) -> Always use the physical 10G link
export NCCL_BOOTSTRAP_IFNAME=eno1

# B. DATA (Heavy Traffic) -> Always use the VPN link
export NCCL_NET_IFNAME=wg0

# C. PREVENT OVERRIDES
# We UNSET NCCL_SOCKET_IFNAME so it doesn't confuse the two roles
unset NCCL_SOCKET_IFNAME

# D. BYPASS THE PLUGIN
# This forces NCCL to use its internal TCP logic instead of RoCE RDMA
export NCCL_NET=Socket
export NCCL_IB_DISABLE=1
export NCCL_DEBUG=INFO
# -------------------------------------------------------------------

NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

echo "Job $SLURM_JOB_ID: Splitting Roles. Bootstrap=eno1, Data=wg0"

# 4. mpirun
# MPI coordinates via wg0 (compatible with head node)
# NCCL uses the specific role variables passed via -x
mpirun -np $NUM_RANKS \
  -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include wg0 \
  --mca oob_tcp_if_include wg0 \
  -x NCCL_DEBUG=INFO \
  -x NCCL_BOOTSTRAP_IFNAME=eno1 \
  -x NCCL_NET_IFNAME=wg0 \
  -x NCCL_NET=Socket \
  -x NCCL_IB_DISABLE=1 \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M -e 2G -f 1.1 -g 1 -n 100 -w 20
