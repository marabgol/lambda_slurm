#!/bin/bash
#SBATCH --job-name=nccl_nfs_test
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --partition=main

# 1. SET SHARED DIRECTORY PATHS
# This ensures Slurm starts in the NFS directory and writes logs there
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_test_%j.out
#SBATCH --error=/lambda/nfs/AIML/home/majid/nccl_test_%j.err

# 2. FORCE NCCL NETWORK SETTINGS
export NCCL_NET=Socket
export NCCL_IB_DISABLE=1
export NCCL_P2P_DISABLE=1
export NCCL_SOCKET_IFNAME=wg0
export NCCL_DEBUG=INFO

# 3. COORDINATION (Using the WireGuard IP of node-01)
export MASTER_IP="192.168.37.3"
export NCCL_COMM_ID="${MASTER_IP}:12345"

# 4. PATH TO BINARY (Already on NFS)
NCCL_TEST_BIN="/lambda/nfs/AIML/nccl-tests/build/reduce_scatter_perf"

echo "Job started from: $(pwd)"
echo "Using Master IP: $MASTER_IP on interface $NCCL_SOCKET_IFNAME"

# 5. RUN WITH EXPLICIT RANK MAPPING
# We use single quotes for the bash command so that the variables 
# are evaluated on the worker nodes, not the login node.
srun --ntasks=2 --ntasks-per-node=1 \
    bash -c '
        export NCCL_RANK=$SLURM_PROCID
        export NCCL_WORLD_SIZE=$SLURM_NTASKS
        echo "Rank $NCCL_RANK reporting from $(hostname)"
        
        # Execute the binary
        '"$NCCL_TEST_BIN"' -b 8 -e 128M -f 2 -g 1 -c 1
    '

