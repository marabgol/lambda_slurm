#!/bin/bash
#SBATCH --job-name=enroot_a10
#SBATCH --partition=main      # Make sure this matches your partition name
#SBATCH --gres=gpu:1         # Request 1 A10 GPU
#SBATCH --nodes=1
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/enroot.%j.out


# 1. Fix the "Missing /run/user" error
# Create a temporary runtime directory in /tmp (which is local and writable)
export ENROOT_RUNTIME_PATH="/tmp/enroot-runtime-$(id -u)"
mkdir -p "$ENROOT_RUNTIME_PATH"

# 2. Fix the NFS Home Directory issue
# Point Enroot to your actual NFS data location
export ENROOT_DATA_PATH="/lambda/nfs/AIML/home/majid/.enroot/data"
mkdir -p "$ENROOT_DATA_PATH"

# 3. Import/Create the image (using your NFS path)
IMAGE_PATH="/lambda/nfs/AIML/home/majid/alpine.sqsh"

if [ ! -f "$IMAGE_PATH" ]; then
    enroot import -o "$IMAGE_PATH" docker://alpine
fi

# 4. Create the container (if it doesn't exist)
if ! enroot list | grep -q "my_alpine"; then
    enroot create --name my_alpine "$IMAGE_PATH"
fi

# 5. Start the container
enroot start --nv my_alpine whoami
