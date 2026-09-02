#!/bin/bash
#SBATCH --job-name=nccl_final
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --partition=main
#SBATCH --error=/lambda/nfs/AIML/home/%u/nccl_final_%j.out
#SBATCH --output=/lambda/nfs/AIML/home/%u/nccl_final_%j.out

# 1. FORCE standard TCP Sockets (ignore the RoCE/InfiniBand plugins)
export NCCL_NET=Socket
export NCCL_IB_DISABLE=1
export NCCL_NET_GDR_LEVEL=0
export NCCL_P2P_DISABLE=1

# 2. FORCE the interface to WireGuard
export NCCL_SOCKET_IFNAME=wg0

# 3. SET MASTER IP (Node-01's wg0 IP)
# We use the hardcoded IP from your previous output to be 100% sure
export MASTER_IP="192.168.37.3"
export NCCL_COMM_ID="${MASTER_IP}:12345"

# 4. DEBUGGING
export NCCL_DEBUG=INFO

echo "Starting NCCL test on 2 nodes..."
echo "Master IP: $MASTER_IP"

NCCL_TEST_BIN="/lambda/nfs/AIML/nccl-tests/build/reduce_scatter_perf"

# 5. THE SRUN WRAPPER
# We must use bash -c to ensure that $SLURM_PROCID is evaluated 
# on each node separately to set the NCCL_RANK.
srun --ntasks=2 --ntasks-per-node=1 --export=ALL \
    bash -c "
        export NCCL_RANK=\$SLURM_PROCID;
        export NCCL_WORLD_SIZE=\$SLURM_NTASKS;
        echo 'Node \$(hostname) is Rank \$NCCL_RANK of \$NCCL_WORLD_SIZE';
        $NCCL_TEST_BIN -b 8 -e 128M -f 2 -g 1 -c 1
    "
