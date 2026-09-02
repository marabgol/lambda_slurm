#!/bin/sh
#SBATCH --job-name=pyxis_basic_test
#SBATCH --nodes=1                   # Request both nodes
#SBATCH --ntasks-per-node=1         # 1 task per node
#SBATCH --output=pyxis_test_%j.out  # Standard output log
#SBATCH --error=pyxis_test_%j.err   # Error log
#SBATCH --chdir=/home/majid
#SBATCH --output=/home/majid/pyxis.%j.out

# --- Pyxis Specific Flags ---
# Replace with the actual absolute path to your .sqsh file
#SBATCH --container-image=/home/majid/alpine.sqsh
#SBATCH --container-mounts=/home/majid:/home/majid

echo "--- Step 1: Check Hostnames from inside the container ---"
srun hostname

echo "--- Step 2: Verify OS inside container (Should be Alpine) ---"
srun cat /etc/os-release | grep PRETTY_NAME

echo "--- Step 3: Verify Mounts (Should see your home directory) ---"
srun ls -l /home/majid/*.sqsh

echo "--- Step 4: Verify Architecture (Should be x86_64 on workers) ---"
srun uname -m
