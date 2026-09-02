#!/bin/bash
#SBATCH --job-name=nccl_manual_fix
#SBATCH --partition=main
#SBATCH --nodes=3
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --time=01:00:00
#SBATCH --output=/lambda/nfs/AIML/home/%u/nccl_test.%j.out
#SBATCH --error=/lambda/nfs/AIML/home/%u/nccl_test.%j.err

set -e

# 1. Identify the Master Node (the first node in the list)
# We need its IP address on the eno1 network
MASTER_NODE=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
MASTER_IP=$(srun --nodes=1 --ntasks=1 -w $MASTER_NODE ip -4 addr show eno1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

# 2. NCCL Environment Setup
export NCCL_DEBUG=INFO
export NCCL_IB_DISABLE=1
export NCCL_NET=Socket
export NCCL_SOCKET_IFNAME=eno1

# 3. Use srun to launch the test
# We manually set NCCL_RANK and NCCL_WORLD_SIZE using Slurm variables
# We set NCCL_COMM_ID to point everyone to the same Master IP and a random port
echo "Master Node: $MASTER_NODE ($MASTER_IP)"

srun --jobid=$SLURM_JOB_ID \
     --export=ALL \
     bash -c "
        export NCCL_RANK=\$SLURM_PROCID;
        export NCCL_WORLD_SIZE=\$SLURM_NTASKS;
        export NCCL_COMM_ID='$MASTER_IP:12345';
        /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf -b 8M -e 2G -f 1.1 -g 1 -n 100 -w 20
     "
