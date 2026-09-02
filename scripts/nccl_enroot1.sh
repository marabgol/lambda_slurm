#!/bin/bash
#SBATCH --job-name=nccl_multi_node
#SBATCH --nodes=2                    # Use both nodes
#SBATCH --ntasks-per-node=1          # 1 process per node
#SBATCH --gres=gpu:1                 # Request 1 GPU per node
#SBATCH --cpus-per-task=4            # Adjust based on your CPU
#SBATCH --output=nccl_%j.out

# --- NCCL Network Tuning ---
export NCCL_DEBUG=INFO
export NCCL_IB_DISABLE=1             # Set to 0 if you have InfiniBand
# Replace 'eth0' with the interface name from 'ip addr' on node-01
export NCCL_SOCKET_IFNAME=eth0       

echo "Running NCCL check on nodes: $SLURM_JOB_NODELIST"

# Launch the CUDA container across both nodes
srun --container-image=/home/majid/cuda-base.sqsh \
     --container-mounts=/home/majid:/home/majid \
     python3 /home/majid/your_training_script.py
