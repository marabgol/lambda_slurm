#!/bin/bash
#SBATCH --job-name=nccl_hpcx_fix
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_hpcx.%j.out

set -e

# 1. FIX SYSTEM MEMORY LIMITS (Crucial for HPC-X/UCX)
# This allows UCX to lock the memory it needs for the network card
ulimit -l unlimited
ulimit -s unlimited

# 2. Initialize HPC-X
HPCX_PATH="/lambda/nfs/AIML/hpcx/hpcx-v2.21.3-gcc-doca_ofed-ubuntu22.04-cuda12-x86_64"
source ${HPCX_PATH}/hpcx-init.sh
hpcx_load

# 3. CAPTURE VPN IP FOR BOOTSTRAP (wg0)
MASTER_NODE=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
MASTER_IP=$(srun --nodes=1 --ntasks=1 -w $MASTER_NODE ip -4 addr show wg0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

# 4. NCCL SPLIT CONFIG
export NCCL_COMM_ID="$MASTER_IP:12345"  # Bootstrap via wg0
export NCCL_SOCKET_IFNAME=eno1           # Data via eno1
export NCCL_NET=Socket
export NCCL_IB_DISABLE=1
export NCCL_NET_PLUGIN=none
export NCCL_DEBUG=INFO

# 5. UCX CONFIG (To quiet the errors)
# Tell UCX to ignore the RDMA hardware since we are forcing TCP for this test
export UCX_TLS=tcp,self
export UCX_NET_DEVICES=eno1

NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

# 6. RUN
# We add -x UCX_TLS to ensure the worker nodes also ignore the RDMA memory pinning
mpirun -np $NUM_RANKS -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include wg0 \
  --mca oob_tcp_if_include wg0 \
  -x NCCL_DEBUG=INFO \
  -x NCCL_COMM_ID="$NCCL_COMM_ID" \
  -x NCCL_SOCKET_IFNAME=eno1 \
  -x NCCL_NET=Socket \
  -x NCCL_IB_DISABLE=1 \
  -x NCCL_NET_PLUGIN=none \
  -x UCX_TLS=tcp,self \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M -e 16G -f 1.1 -g 1 -n 50 -w 20
