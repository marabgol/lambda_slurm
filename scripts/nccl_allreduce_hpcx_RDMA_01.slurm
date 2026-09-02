#!/bin/bash
#SBATCH --job-name=nccl_ROCE_v2
#SBATCH --nodes=3
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_roce.%j.out

set -e

# 1. Initialize HPC-X (Necessary for high-performance RDMA drivers)
HPCX_PATH="/lambda/nfs/AIML/hpcx/hpcx-v2.21.3-gcc-doca_ofed-ubuntu22.04-cuda12-x86_64"
source ${HPCX_PATH}/hpcx-init.sh
hpcx_load

# 2. CRITICAL: Memory Pinning for RDMA
# RDMA cannot work without locking memory.
ulimit -l unlimited
ulimit -s unlimited

# 3. CAPTURE VPN IP FOR BOOTSTRAP (wg0)
MASTER_NODE=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
MASTER_IP=$(srun --nodes=1 --ntasks=1 -w $MASTER_NODE ip -4 addr show wg0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

# 4. FORCE ROCE v2 CONFIGURATION
# -------------------------------------------------------------------
export NCCL_DEBUG=INFO
export NCCL_COMM_ID="$MASTER_IP:12345"

# Enable RDMA (InfiniBand/RoCE)
export NCCL_IB_DISABLE=0
export NCCL_NET=IB                # Use InfiniBand/Verbs transport

# Hardware Mapping
export NCCL_IB_HCA=mlx5_0:1       # Use Port 1 of Mellanox device
export NCCL_IB_GID_INDEX=3        # Force RoCE v2 (based on your show_gids)

# Performance Tuning for 50G
export NCCL_IB_RETRY_CNT=7
export NCCL_IB_TIMEOUT=20
export NCCL_NET_GDR_LEVEL=0       # Standard path for basic Ethernet NICs
# -------------------------------------------------------------------

NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

echo "Starting RoCE v2 RDMA Test: Bootstrap via wg0, Data via mlx5_0 (Index 3)"

# 5. RUN
mpirun -np $NUM_RANKS -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include eno \
  --mca oob_tcp_if_include wg0 \
  -x NCCL_DEBUG=INFO \
  -x NCCL_COMM_ID="$NCCL_COMM_ID" \
  -x NCCL_IB_DISABLE=0 \
  -x NCCL_IB_HCA=mlx5_0:1 \
  -x NCCL_IB_GID_INDEX=3 \
  -x NCCL_NET=IB \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M -e 16G -f 1.1 -g 1 -n 50 -w 10
