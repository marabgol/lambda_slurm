#!/bin/bash
#SBATCH --job-name=enroot_a10
#SBATCH --partition=main      # Make sure this matches your partition name
#SBATCH --gres=gpu:1         # Request 1 A10 GPU
#SBATCH --nodes=1
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/enroot.%j.out

# 1. Pull the image (Best to do this on a shared drive or once per node)
if [ ! -f ~/nvidia_pytorch.sqsh ]; then
    enroot import -o ~/nvidia_pytorch.sqsh docker://nvcr.io/nvidia/pytorch:23.10-py3
fi

# 2. Create the container bundle
enroot create --name pytorch_gpu ~/nvidia_pytorch.sqsh

# 3. Run with GPU support
# The --nv flag is critical: it tells Enroot to inject the A10 drivers
enroot start --nv pytorch_gpu python -c "import torch; print(f'A10 GPU Detected: {torch.cuda.is_available()}')"

