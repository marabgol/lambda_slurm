#!/bin/bash
#SBATCH --job-name=nccl_true_split
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_split.%j.out

set -e

# 1. Environment Paths
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# 2. TRUE SPLIT CONFIGURATION
# -------------------------------------------------------------------
# NCCL_SOCKET_IFNAME only handles the Bootstrap (Control)
export NCCL_SOCKET_IFNAME=eno1      

# NCCL_NET_IFNAME only handles the Data (Heavy traffic)
export NCCL_NET_IFNAME=wg0          

# IMPORTANT: Remove or Comment out NCCL_NET=Socket 
# export NCCL_NET=Socket <--- DO NOT USE THIS

export NCCL_IB_DISABLE=1            # Disables RoCE/InfiniBand
export NCCL_NET_GDR_LEVEL=0
export NCCL_DEBUG=INFO
# -------------------------------------------------------------------

# 3. Setup Ranks
NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

# 4. mpirun
# Pass both IFNAME variables to the nodes
mpirun -np $NUM_RANKS \
  -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include eno1 \
  --mca oob_tcp_if_include eno1 \
  -x NCCL_DEBUG \
  -x NCCL_SOCKET_IFNAME=eno1 \
  -x NCCL_NET_IFNAME=wg0 \
  -x NCCL_IB_DISABLE=1 \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M -e 2G -f 1.1 -g 1 -n 100 -w 20
