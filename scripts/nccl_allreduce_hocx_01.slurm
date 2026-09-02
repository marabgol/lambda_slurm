#!/bin/bash
#SBATCH --job-name=nccl_hpcx_split
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_hpcx.%j.out

set -e

# 1. Initialize HPC-X Environment
HPCX_PATH="/lambda/nfs/AIML/hpcx/hpcx-v2.21.3-gcc-doca_ofed-ubuntu22.04-cuda12-x86_64"
source ${HPCX_PATH}/hpcx-init.sh
hpcx_load

# 2. CAPTURE VPN IP FOR BOOTSTRAP (wg0)
# This ensures the handshake stays in the VPN tunnel
MASTER_NODE=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
MASTER_IP=$(srun --nodes=1 --ntasks=1 -w $MASTER_NODE ip -4 addr show wg0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

# 3. NCCL ROLE-BASED CONFIGURATION
# -------------------------------------------------------------------
# Control Plane: Force Handshake to the VPN IP
export NCCL_COMM_ID="$MASTER_IP:12345"  

# Data Plane: Force 2GB buffers to the physical 10G wire
export NCCL_SOCKET_IFNAME=eno1           

# Bypass high-speed RDMA plugins to ensure it uses the eno1 TCP stack
export NCCL_NET=Socket
export NCCL_IB_DISABLE=1
export NCCL_NET_PLUGIN=none
export NCCL_DEBUG=INFO
# -------------------------------------------------------------------

NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

echo "HPC-X Job: Control=wg0 ($MASTER_IP), Data=eno1"

# 4. Execute using HPC-X mpirun
# We still use --mca flags to ensure MPI itself coordinates via VPN (wg0)
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
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M -e 16G -f 1.1 -g 1 -n 50 -w 20
