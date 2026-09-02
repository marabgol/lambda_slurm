#!/bin/bash
#SBATCH --job-name=nccl-allreduce
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
##SBATCH --gres=gpu:a10:1
#SBATCH --gres=gpu:1
#SBATCH --partition=main
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_%j.out
#SBATCH --error=/lambda/nfs/AIML/home/majid/nccl_%j.err

# --- Environment Setup ---
# Load CUDA/NCCL if you use modules, otherwise ensure they are in your PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64

# --- NCCL Ethernet Tuning ---
# 1. Force NCCL to use the specific Ethernet interface (CRITICAL)
# Replace 'eth0' with your actual interface name (e.g., ens3, enp1s0)
export NCCL_SOCKET_IFNAME=eno1

# 2. Enable Debugging so we can see if it's using the right path
export NCCL_DEBUG=INFO

# 3. Since you are on 10G Ethernet, tell NCCL to expect TCP
export NCCL_IB_DISABLE=1

# --- Run the Test ---
# We use srun to launch 1 process per node. 
# -b: min bytes, -e: max bytes, -f: step multiplier, -g: GPUs per node
srun /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf -b 8 -e 1G -f 2 -g 1
