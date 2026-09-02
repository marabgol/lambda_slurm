#!/bin/bash
#SBATCH --job-name=nccl_split_FINAL
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

# 2. CAPTURE THE PHYSICAL IP FOR BOOTSTRAP
# We get the 10.19.x.x IP of the first node in the job
MASTER_NODE=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
# We use srun to ask that specific node for its eno1 IP
MASTER_IP=$(srun --nodes=1 --ntasks=1 -w $MASTER_NODE ip -4 addr show eno1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

# 3. THE TRUE SPLIT CONFIGURATION
# -------------------------------------------------------------------
# A. Force the Handshake to the physical IP we just found
export NCCL_COMM_ID="$MASTER_IP:12345"

# B. Force the Data Plane to ONLY see wg0
export NCCL_SOCKET_IFNAME=wg0

# C. Force Socket mode and disable high-speed hardware plugins
export NCCL_NET=Socket
export NCCL_IB_DISABLE=1
export NCCL_NET_PLUGIN=none

export NCCL_DEBUG=INFO
# -------------------------------------------------------------------

NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

echo "Master IP (eno1): $MASTER_IP"
echo "Data Interface: wg0"

# 4. mpirun
# MPI coordinates via wg0 (Head Node compatibility)
# NCCL uses the variables passed via -x
mpirun -np $NUM_RANKS \
  -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include wg0 \
  --mca oob_tcp_if_include wg0 \
  -x NCCL_DEBUG=INFO \
  -x NCCL_COMM_ID="$NCCL_COMM_ID" \
  -x NCCL_SOCKET_IFNAME=wg0 \
  -x NCCL_NET=Socket \
  -x NCCL_IB_DISABLE=1 \
  -x NCCL_NET_PLUGIN=none \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M -e 2G -f 1.1 -g 1 -n 100 -w 20
