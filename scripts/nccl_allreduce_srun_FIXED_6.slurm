#!/bin/bash
#SBATCH --job-name=nccl_multi_node
#SBATCH --partition=main
#SBATCH --nodes=2                  # Change this number to 2, 3, 4, etc.
#SBATCH --ntasks-per-node=1        
#SBATCH --gres=gpu:1               
#SBATCH --time=01:00:00
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/%u/nccl_test.%j.out

set -e

# 1. MPI and Library Paths
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# 2. NCCL Settings
export NCCL_DEBUG=INFO
export NCCL_SOCKET_IFNAME=eno1
export NCCL_IB_DISABLE=1
export NCCL_NET=Socket

# 3. Dynamic setup
# This reads the rank count directly from Slurm
NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

echo "Job $SLURM_JOB_ID starting with $NUM_RANKS ranks on $HOSTS"

# 4. Execute mpirun
mpirun -np $NUM_RANKS \
  -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include eno1 \
  --mca oob_tcp_if_include eno1 \
  -x NCCL_DEBUG \
  -x NCCL_SOCKET_IFNAME \
  -x NCCL_IB_DISABLE \
  -x NCCL_NET \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M \
    -e 2G \
    -f 1.1 \
    -g 1 \
    -n 100 \
    -w 20
