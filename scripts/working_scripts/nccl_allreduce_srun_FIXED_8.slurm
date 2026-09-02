#!/bin/bash
#SBATCH --job-name=nccl_oversubscribe
#SBATCH --partition=main
#SBATCH --nodes=1                  
#SBATCH --ntasks-per-node=1        # 4 processes per node (8 total)
#SBATCH --gres=gpu:8               # Physical limit: 1 GPU
#SBATCH --time=01:00:00
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_multi.%j.out

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

# 3. Dynamic setup
NUM_RANKS=$SLURM_NTASKS
TASKS_PER_NODE=$SLURM_NTASKS_PER_NODE
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk -v tpn="$TASKS_PER_NODE" '{print $1":"tpn}' | paste -d, -s)

echo "Total Ranks: $NUM_RANKS (4 ranks sharing 1 GPU per node)"

# 4. Execute mpirun with a BASH WRAPPER
# We move the CUDA_VISIBLE_DEVICES into a bash command string.
# This ensures that Rank 0, 1, 2, and 3 ALL use device index 0.
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
  bash -c "export CUDA_VISIBLE_DEVICES=0; /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf -b 8M -e 2G -f 1.1 -g 1 -n 5 -w 20"
