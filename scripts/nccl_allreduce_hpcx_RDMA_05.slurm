#!/bin/bash
#SBATCH --job-name=nccl_MAX_SPEED
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/max_speed_test.%j.out

# Load HPC-X
source /lambda/nfs/AIML/hpcx/hpcx-v2.21.3-gcc-doca_ofed-ubuntu22.04-cuda12-x86_64/hpcx-init.sh
hpcx_load
ulimit -l unlimited

# Capture IP
MASTER_NODE=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
MASTER_PHYS_IP=$(srun --nodes=1 --ntasks=1 -w $MASTER_NODE ip -4 addr show eno1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

# Set Max Performance Flags
export NCCL_COMM_ID="$MASTER_PHYS_IP:12345"
export NCCL_IB_DISABLE=0
export NCCL_NET=IB
export NCCL_IB_HCA=mlx5_0:1
export NCCL_IB_GID_INDEX=3
export NCCL_MIN_NCHANNELS=16  # Force many parallel lanes to fill the 50G pipe

# Run the raw binary (Much faster than Python)
# -n 100: Do 100 iterations per size to keep the pipe full
mpirun -np 2 \
  --mca btl_tcp_if_include wg0 --mca oob_tcp_if_include wg0 \
  -x NCCL_COMM_ID -x NCCL_IB_DISABLE=0 -x NCCL_IB_HCA=mlx5_0:1 -x NCCL_IB_GID_INDEX=3 -x NCCL_NET=IB -x NCCL_MIN_NCHANNELS=16 \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf -b 1G -e 4G -f 2 -g 1 -n 100 -w 10
