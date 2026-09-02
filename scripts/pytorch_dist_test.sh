#!/bin/bash
#SBATCH --job-name=pytorch_nccl_test
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:10:1
#SBATCH --cpus-per-task=4
#SBATCH --partition=main  # Change this to your actual partition

# 1. NCCL Configuration
export NCCL_DEBUG=INFO
export NCCL_IB_DISABLE=1
export NCCL_SOCKET_IFNAME=eno1

# 2. PyTorch Distributed Master Info
# We get the IP of the first node assigned by Slurm
export MASTER_ADDR=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
export MASTER_PORT=12345

# 3. Launch the Python script
# srun will automatically handle RANK and WORLD_SIZE for PyTorch
srun python3 -u distributed_test.py
