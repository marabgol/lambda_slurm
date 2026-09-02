#!/bin/bash
#SBATCH --job-name=nccl_split_net
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

# 2. SPLIT NETWORK CONFIGURATION
# ---------------------------------------------------------
export NCCL_BOOTSTRAP_IFNAME=eno1    # CONTROL on physical Ethernet
export NCCL_SOCKET_IFNAME=wg0       # DATA on VPN tunnel
# ---------------------------------------------------------

export NCCL_IB_DISABLE=1            # Disable RDMA to force wg0/TCP
export NCCL_NET=Socket              # Force TCP stack for the VPN
export NCCL_DEBUG=INFO

# 3. Dynamic setup
NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

echo "Starting Split-Network Test: Control=eno1, Data=wg0"

# 4. mpirun
# We also tell MPI to use eno1 for its own management to keep startup fast
mpirun -np $NUM_RANKS \
  -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include eno1 \
  --mca oob_tcp_if_include eno1 \
  -x NCCL_DEBUG \
  -x NCCL_BOOTSTRAP_IFNAME=eno1 \
  -x NCCL_SOCKET_IFNAME=wg0 \
  -x NCCL_IB_DISABLE=1 \
  -x NCCL_NET=Socket \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M -e 2G -f 1.1 -g 1 -n 100 -w 20
