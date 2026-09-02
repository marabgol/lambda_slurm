#!/bin/bash
#SBATCH --job-name=nccl_ROCE_v2
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_roce.%j.out

set -e

# 1. HPC-X Environment & Memory Limits
HPCX_PATH="/lambda/nfs/AIML/hpcx/hpcx-v2.21.3-gcc-doca_ofed-ubuntu22.04-cuda12-x86_64"
source ${HPCX_PATH}/hpcx-init.sh
hpcx_load
ulimit -l unlimited
ulimit -s unlimited

# 2. CAPTURE VPN IP FOR BOOTSTRAP (wg0)
# This keeps the management traffic on the VPN (compatible with head node)
MASTER_NODE=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
MASTER_IP=$(srun --nodes=1 --ntasks=1 -w $MASTER_NODE ip -4 addr show wg0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

# 3. FORCE ROCE v2 (RDMA) FOR DATA
# -------------------------------------------------------------------
export NCCL_DEBUG=INFO
export NCCL_COMM_ID="$MASTER_IP:12345"  # Handshake on VPN

# ENABLE RDMA (This bypasses the 2.68Gbps TCP ceiling)
export NCCL_IB_DISABLE=0          
export NCCL_NET=IB                

# HARDWARE BINDING (Force data to the 50G mlx5_0 card)
export NCCL_IB_HCA=mlx5_0:1       
export NCCL_IB_GID_INDEX=3         # Based on your show_gids output
export NCCL_NET_IFNAME=eno1        # Resolve peers via the 10.19.x.x network

# Performance Tuning for 50G
export NCCL_IB_RETRY_CNT=7
export NCCL_IB_TIMEOUT=20
export NCCL_MIN_NCHANNELS=8        # Parallel data streams
# -------------------------------------------------------------------

NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

echo "Starting RoCE RDMA Test: Bootstrap=wg0, Data=RoCE (eno1/Index 3)"

# 4. RUN
mpirun -np $NUM_RANKS -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include wg0 \
  --mca oob_tcp_if_include wg0 \
  -x NCCL_DEBUG=INFO \
  -x NCCL_COMM_ID="$NCCL_COMM_ID" \
  -x NCCL_IB_DISABLE=0 \
  -x NCCL_IB_HCA=mlx5_0:1 \
  -x NCCL_IB_GID_INDEX=3 \
  -x NCCL_NET=IB \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M -e 16G -f 1.1 -g 1 -n 20 -w 5
