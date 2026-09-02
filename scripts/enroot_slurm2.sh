#!/bin/bash
#SBATCH --job-name=enroot_a10
#SBATCH --partition=main
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --chdir=/home/majid
#SBATCH --output=/home/majid/enroot.%j.out

# 1. Enroot Runtime Setup (Crucial for Slurm)
export ENROOT_RUNTIME_PATH="/tmp/enroot-runtime-$(id -u)"
mkdir -p "$ENROOT_RUNTIME_PATH"

# 2. Use the standard path (thanks to your symlink!)
IMAGE_PATH="/home/majid/alpine.sqsh"

# 3. Create container if it doesn't exist
if ! enroot list | grep -q "^alpine$"; then
    enroot create --name alpine "$IMAGE_PATH"
fi

# 4. Run the command
# We use -m to ensure the container sees your NFS home as /home/majid
enroot start -m /home/majid:/home/majid alpine nvidia-smi
