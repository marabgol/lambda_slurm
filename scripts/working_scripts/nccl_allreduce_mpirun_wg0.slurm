#!/bin/bash
#SBATCH --job-name=nccl_vpn_1ppn
#SBATCH --partition=main
#SBATCH --nodes=2                  # Adjust nodes as needed
#SBATCH --ntasks-per-node=1        # Exactly 1 process per node
#SBATCH --gres=gpu:1               # Exactly 1 GPU per node
#SBATCH --time=01:00:00
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/%u/nccl_vpn.%j.out

set -e

# 1. MPI and Library Paths
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# 2. NCCL Settings for VPN (wg0)
export NCCL_DEBUG=INFO
export NCCL_SOCKET_IFNAME=wg0       # Use WireGuard VPN
export NCCL_IB_DISABLE=1            # Disable IB for VPN
export NCCL_NET=Socket             # Use standard TCP stack
export NCCL_NET_GDR_LEVEL=0

# 3. Dynamic setup
NUM_RANKS=$SLURM_NTASKS
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

echo "Starting VPN test on $NUM_RANKS nodes via wg0"

# 4. Execute mpirun
# We swap the --mca includes to wg0 so MPI coordinates over the VPN
mpirun -np $NUM_RANKS \
  -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include wg0 \
  --mca oob_tcp_if_include wg0 \
  -x NCCL_DEBUG \
  -x NCCL_SOCKET_IFNAME=wg0 \
  -x NCCL_IB_DISABLE=1 \
  -x NCCL_NET=Socket \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M \
    -e 2G \
    -f 1.1 \
    -g 1 \
    -n 1 \
    -w 20
