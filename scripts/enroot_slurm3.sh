#!/bin/bash
#SBATCH --job-name=enroot_a10
#SBATCH --partition=main
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --chdir=/home/majid
#SBATCH --output=/home/majid/enroot.%j.out

# 1. Enroot Setup
export ENROOT_RUNTIME_PATH="/tmp/enroot-runtime-$(id -u)"
mkdir -p "$ENROOT_RUNTIME_PATH"

# 2. Tell Enroot to pass all GPUs to the container
export NVIDIA_VISIBLE_DEVICES=all

# 3. Use a CUDA-ready image (Ubuntu-based)
IMAGE_PATH="/home/majid/cuda-base.sqsh"
if [ ! -f "$IMAGE_PATH" ]; then
    enroot import -o "$IMAGE_PATH" docker://nvidia/cuda:12.0.1-base-ubuntu22.04
fi

# 4. Create container
if ! enroot list | grep -q "^cuda_test$"; then
    enroot create --name cuda_test "$IMAGE_PATH"
fi

# 5. Run nvidia-smi
enroot start -m /home/majid:/home/majid cuda_test nvidia-smi
