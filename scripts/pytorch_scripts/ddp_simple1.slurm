#!/bin/bash
#SBATCH --job-name=ddp_simple
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --time=02:00:00
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/ddp_simple.%j.out

set -e

# 1. Environment and Memory Limits
ulimit -l unlimited
ulimit -s unlimited
export MPI_HOME="/usr/mpi/gcc/openmpi-4.1.7rc1"
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# 2. CAPTURE PHYSICAL IP (eno1)
# We use the 10.19.x.x address for the Master node
MASTER_NODE=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
MASTER_PHYS_IP=$(srun --nodes=1 --ntasks=1 -w $MASTER_NODE ip -4 addr show eno1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

# 3. NCCL PURE PHYSICAL CONFIG
export NCCL_DEBUG=INFO
export NCCL_SOCKET_IFNAME=eno1      # Handshake on 50G
export NCCL_NET_IFNAME=eno1         # Data on 50G
export NCCL_IB_DISABLE=1            # Start with TCP for stability; change to 0 for RoCE later

# 4. PYTORCH CONTROL PLANE (Moving Gloo/TCPStore to eno1)
export MASTER_ADDR=$MASTER_PHYS_IP
export MASTER_PORT=12345
export WORLD_SIZE=$SLURM_NTASKS
export GLOO_SOCKET_IFNAME=eno1      # Use physical wire for management
export TP_SOCKET_IFNAME=eno1        # Use physical wire for TCPStore

echo "Master Node: $MASTER_NODE at $MASTER_PHYS_IP (eno1)"

# 5. Launch
srun -u bash -c "export RANK=\$SLURM_PROCID;\
 export LOCAL_RANK=\$SLURM_LOCALID;\
 python3 ddp_example.py"
