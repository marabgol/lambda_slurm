#!/bin/bash
#SBATCH --job-name=nccl_oversubscribe
#SBATCH --partition=main
#SBATCH --nodes=1                  # 3 physical nodes
#SBATCH --ntasks-per-node=1        # <--- 4 processes per node (Total 12 ranks)
#SBATCH --gres=gpu:1               # Still only 1 GPU per node
#SBATCH --time=01:00:00
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/%u/nccl_multi.%j.out

set -e

# 1. Environment
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# 2. NCCL Settings
export NCCL_DEBUG=INFO
export NCCL_SOCKET_IFNAME=eno1
export NCCL_IB_DISABLE=1
export NCCL_NET=Socket

# 3. Dynamic setup for Multiple Processes
NUM_RANKS=$SLURM_NTASKS
TASKS_PER_NODE=$SLURM_NTASKS_PER_NODE

# Create host list format: node-01:4,node-02:4,node-03:4
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk -v tpn="$TASKS_PER_NODE" '{print $1":"tpn}' | paste -d, -s)

echo "Total Ranks: $NUM_RANKS (sharing 1 GPU per node)"

# 4. Execute mpirun
# CRITICAL: We add -x CUDA_VISIBLE_DEVICES=0 
# This forces all 4 processes on the node to use the same first GPU.
mpirun -np $NUM_RANKS \
  -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include eno1 \
  --mca oob_tcp_if_include eno1 \
  -x NCCL_DEBUG \
  -x NCCL_SOCKET_IFNAME=eno1 \
  -x NCCL_IB_DISABLE=1 \
  -x NCCL_NET=Socket \
  -x LD_LIBRARY_PATH \
  -x CUDA_VISIBLE_DEVICES=0 \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M \
    -e 2G \
    -f 1.1 \
    -g 1 \
    -n 5 \
    -w 20
