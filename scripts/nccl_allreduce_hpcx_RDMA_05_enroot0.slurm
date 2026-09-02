#!/bin/bash
#SBATCH --job-name=nccl_CONTAINER_RDMA
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/container_speed_test.%j.out

# 1. Capture Master IP (Host Network)
MASTER_NODE=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
MASTER_PHYS_IP=$(srun --nodes=1 --ntasks=1 -w $MASTER_NODE ip -4 addr show eno1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

# 2. Set NCCL & RDMA Environment Variables
export NCCL_COMM_ID="$MASTER_PHYS_IP:12345"
export NCCL_IB_DISABLE=0
export NCCL_NET=IB
export NCCL_IB_HCA=mlx5_0:1
export NCCL_IB_GID_INDEX=3
export NCCL_MIN_NCHANNELS=16
export NCCL_DEBUG=INFO

# 3. HPC-X Path (inside and outside the container)
HPCX_PATH="/lambda/nfs/AIML/hpcx/hpcx-v2.21.3-gcc-doca_ofed-ubuntu22.04-cuda12-x86_64"

# 4. Launch via srun + Pyxis
# We mount the entire /lambda/nfs path so the container can access HPC-X and the tests
srun --container-image=/home/majid/cuda-base.sqsh \
     --container-mounts=/lambda/nfs:/lambda/nfs \
     --export=ALL,LD_LIBRARY_PATH=$HPCX_PATH/nccl/lib:$HPCX_PATH/ucc/lib:$HPCX_PATH/ucx/lib:$LD_LIBRARY_PATH \
     /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf -b 1G -e 4G -f 2 -g 1 -n 100 -w 10
