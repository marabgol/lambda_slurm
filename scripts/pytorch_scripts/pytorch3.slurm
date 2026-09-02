#!/bin/bash
#SBATCH --job-name=pytorch_STRESS
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --time=02:00:00
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/pytorch_stress.%j.out

set -e

# 1. Environment
ulimit -l unlimited
ulimit -s unlimited
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# 2. Capture IPs for Handshake (wg0)
MASTER_NODE=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
MASTER_VPN_IP=$(srun --nodes=1 --ntasks=1 -w $MASTER_NODE ip -4 addr show wg0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

# 3. NCCL SPLIT CONFIG
export NCCL_DEBUG=INFO
export NCCL_COMM_ID="$MASTER_VPN_IP:12345"
export NCCL_BOOTSTRAP_IFNAME=wg0
export NCCL_SOCKET_IFNAME=eno1
export NCCL_NET_IFNAME=eno1
export NCCL_IB_DISABLE=0
export NCCL_IB_GID_INDEX=3
export NCCL_NET=IB

# 4. PYTORCH CONTROL PLANE
export MASTER_ADDR=$MASTER_VPN_IP
export MASTER_PORT=12345
export WORLD_SIZE=$SLURM_NTASKS
export GLOO_SOCKET_IFNAME=wg0
export TP_SOCKET_IFNAME=wg0

# 5. Launch
srun -u bash -c "
    export RANK=\$SLURM_PROCID;
    export LOCAL_RANK=\$SLURM_LOCALID;
    python3 dist_stress3.py
"
