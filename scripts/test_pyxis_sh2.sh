#!/bin/bash
#SBATCH --job-name=pyxis_test
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=pyxis_test_%j.out

# Notice: NO container flags in the header!

echo "--- Step 1: Check Hostnames from inside the container ---"
srun --container-image=/home/majid/alpine.sqsh \
     --container-mounts=/home/majid:/home/majid \
     hostname

echo "--- Step 2: Verify OS inside container ---"
srun --container-image=/home/majid/alpine.sqsh \
     cat /etc/os-release | grep PRETTY_NAME
