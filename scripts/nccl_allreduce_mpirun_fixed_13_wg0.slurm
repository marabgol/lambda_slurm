#!/bin/bash
#SBATCH --job-name=nccl_split_IP
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

# 2. THE IP-BASED SPLIT CONFIG
# -------------------------------------------------------------------
# Force Bootstrap (Control) to the 10.19.x.x network (eno1)
export NCCL_SOCKET_IFNAME=10.19

# Force Network (Data) to the 192.168.37.x network (wg0)
export NCCL_NET_IFNAME=192.168.37

# CRITICAL: We REMOVE NCCL_NET=Socket to let NCCL distinguish 
# between the Socket layer and the Net layer.
unset NCCL_NET

export NCCL_IB_DISABLE=1
export NCCL_DEBUG=INFO
# -------------------------------------------------------------------

# 3. Setup Ranks
NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

# 4. mpirun
mpirun -np $NUM_RANKS \
  -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include eno1 \
  --mca oob_tcp_if_include eno1 \
  -x NCCL_DEBUG=INFO \
  -x NCCL_SOCKET_IFNAME=10.19 \
  -x NCCL_NET_IFNAME=192.168.37 \
  -x NCCL_IB_DISABLE=1 \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M -e 2G -f 1.1 -g 1 -n 100 -w 20
