#!/bin/bash
#SBATCH --job-name=pytorch_nccl_split
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/pytorch_test.%j.out

set -e

# 1. Capture IPs for the PyTorch Handshake
# MASTER_ADDR must be the VPN IP of the first node
MASTER_NODE=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
MASTER_VPN_IP=$(srun --nodes=1 --ntasks=1 -w $MASTER_NODE ip -4 addr show wg0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

# 2. NCCL SPLIT CONFIGURATION
# -------------------------------------------------------------------
export NCCL_DEBUG=INFO
export NCCL_SOCKET_IFNAME=wg0        # HANDSHAKE via VPN
export NCCL_NET_IFNAME=eno1          # DATA via 50G Physical wire

# Toggle this: 1 for TCP (eno1), 0 for RoCE/RDMA (eno1)
export NCCL_IB_DISABLE=1             
# -------------------------------------------------------------------

# 3. PYTORCH DISTRIBUTED SETTINGS
export MASTER_ADDR=$MASTER_VPN_IP
export MASTER_PORT=12345
export WORLD_SIZE=$SLURM_NTASKS

echo "Master Node: $MASTER_NODE at $MASTER_ADDR"

# 4. Launch PyTorch with srun
# We manually set RANK and LOCAL_RANK for each process
srun bash -c "
    export RANK=\$SLURM_PROCID;
    export LOCAL_RANK=\$SLURM_LOCALID;
    python3 dist_test.py
"
