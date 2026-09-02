#!/bin/bash
#SBATCH --job-name=nccl_ROCE_FULLSPEED
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_roce.%j.out

set -e

# 1. Initialize HPC-X
HPCX_PATH="/lambda/nfs/AIML/hpcx/hpcx-v2.21.3-gcc-doca_ofed-ubuntu22.04-cuda12-x86_64"
source ${HPCX_PATH}/hpcx-init.sh
hpcx_load
ulimit -l unlimited

# 2. CAPTURE PHYSICAL IP (eno1) FOR THE GPUs
# The GPUs will use this 10.19.x.x IP to find each other, bypassing the VPN.
MASTER_NODE=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
MASTER_PHYSICAL_IP=$(srun --nodes=1 --ntasks=1 -w $MASTER_NODE ip -4 addr show eno1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

# 3. NCCL High-Speed Settings
export NCCL_DEBUG=INFO
# We point the NCCL Master to the 10.19 IP
export NCCL_COMM_ID="$MASTER_PHYSICAL_IP:12345"

# Force NCCL to use eno1 for its internal data and socket logic
export NCCL_SOCKET_IFNAME=eno1
export NCCL_NET_IFNAME=eno1

# Enable RDMA (RoCE)
export NCCL_IB_DISABLE=0
export NCCL_NET=IB
export NCCL_IB_HCA=mlx5_0:1
export NCCL_IB_GID_INDEX=3
export NCCL_IB_TC=106
export NCCL_IB_RETRY_CNT=7
export NCCL_IB_TIMEOUT=22

NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

# 4. RUN
# MPI coordinates via wg0 (So the Head Node can manage the job)
# NCCL is told via -x variables to use eno1 (So the GPUs go fast)
mpirun -np $NUM_RANKS -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include wg0 \
  --mca oob_tcp_if_include wg0 \
  -x NCCL_DEBUG=INFO \
  -x NCCL_COMM_ID="$NCCL_COMM_ID" \
  -x NCCL_SOCKET_IFNAME=eno1 \
  -x NCCL_NET_IFNAME=eno1 \
  -x NCCL_IB_DISABLE=0 \
  -x NCCL_IB_HCA=mlx5_0:1 \
  -x NCCL_IB_GID_INDEX=3 \
  -x NCCL_NET=IB \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests-hpcx/build/all_reduce_perf -b 8M -e 16G -f 1.1 -g 1 -n 20 -w 5
