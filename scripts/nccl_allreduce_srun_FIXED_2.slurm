#!/bin/bash
#SBATCH --job-name=nccl_eth_test
#SBATCH --partition=main
#SBATCH --nodes=3                  # Adjust to number of nodes
#SBATCH --ntasks-per-node=1        # 1 process per node
#SBATCH --cpus-per-task=4          
#SBATCH --gres=gpu:1               
#SBATCH --time=01:00:00            
#SBATCH --output=/lambda/nfs/AIML/home/%u/nccl_test.%j.out
#SBATCH --error=/lambda/nfs/AIML/home/%u/nccl_test.%j.err

set -e
set -x

# 1. MPI Environment
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# 2. NCCL Environment - Switching to eno1
export NCCL_SOCKET_IFNAME=eno1      # Use Physical Ethernet
export NCCL_IB_DISABLE=1            # Disable InfiniBand to force Ethernet TCP
export NCCL_NET_GDR_LEVEL=0         
export NCCL_DEBUG=INFO

# 3. Generate Dynamic Host List
# Creates: node-01:1,node-02:1,node-03:1
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

echo "=========================================="
echo "Starting NCCL Test on Ethernet (eno1)"
echo "Nodes: $HOSTS"
echo "=========================================="

# 4. Running mpirun
# --mca btl_tcp_if_include eno1: Forces MPI to coordinate on eno1
# -x: Passes environment variables to all nodes
mpirun -np $SLURM_JOB_NUM_NODES \
  -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include eno1 \
  --mca oob_tcp_if_include eno1 \
  -x NCCL_SOCKET_IFNAME=eno1 \
  -x NCCL_IB_DISABLE=1 \
  -x NCCL_NET_GDR_LEVEL=0 \
  -x NCCL_DEBUG=INFO \
  -x LD_LIBRARY_PATH \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M \
    -e 2G \
    -f 1.1 \
    -g 1 \
    -n 100 \
    -w 20

echo "=========================================="
echo "Test Complete"
echo "=========================================="
