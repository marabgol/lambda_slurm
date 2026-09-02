#!/bin/bash
#SBATCH --job-name=nccl_fix
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --partition=main
#SBATCH --output=/home/%u/nccl_fix_%j.out
#SBATCH --chdir=/tmp           # Avoid the home directory error

# 1. Network Configuration
export NCCL_NET=Socket
export NCCL_IB_DISABLE=1
export NCCL_P2P_DISABLE=1
export NCCL_SOCKET_IFNAME=wg0
export NCCL_DEBUG=INFO

# 2. Master Coordination (Using Node-01's WireGuard IP)
export MASTER_IP="192.168.37.3"
export NCCL_COMM_ID="${MASTER_IP}:12345"

# 3. Path to Binary
NCCL_TEST_BIN="/lambda/nfs/AIML/nccl-tests/build/reduce_scatter_perf"

echo "Launching NCCL on nodes via wg0..."

# 4. THE CRITICAL RUN COMMAND
# We use single quotes '' around the command so the local shell 
# doesn't touch the variables. They will be evaluated on the worker nodes.
srun --ntasks=2 --ntasks-per-node=1 \
    bash -c 'export NCCL_RANK=$SLURM_PROCID; \
             export NCCL_WORLD_SIZE=$SLURM_NTASKS; \
             echo "I am rank $NCCL_RANK on $(hostname)"; \
             '"$NCCL_TEST_BIN"' -b 8 -e 128M -f 2 -g 1 -c 1'
