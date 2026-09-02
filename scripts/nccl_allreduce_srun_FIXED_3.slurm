#!/bin/bash
#SBATCH --job-name=nccl_fix
#SBATCH --nodes=3
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --output=/lambda/nfs/AIML/home/%u/nccl_test.%j.out

set -e

# 1. Environment
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# 2. Force Ethernet (eno1) and Disable InfiniBand
export NCCL_SOCKET_IFNAME=eno1
export NCCL_IB_DISABLE=1
export NCCL_NET=Socket
export NCCL_DEBUG=INFO

# 3. Dynamic Host List
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

echo "Running on hosts: $HOSTS"

# 4. mpirun
# Note: mpirun will now pass the Rank and Size info to the MPI-enabled binary
mpirun -np 3 \
  -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include eno1 \
  --mca oob_tcp_if_include eno1 \
  -x NCCL_SOCKET_IFNAME \
  -x NCCL_IB_DISABLE \
  -x NCCL_NET \
  -x NCCL_DEBUG \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf -b 8M -e 2G -f 1.1 -g 1 -n 100 -w 20
