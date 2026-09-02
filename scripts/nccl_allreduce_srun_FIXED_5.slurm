#!/bin/bash
#SBATCH --job-name=nccl_3node_final
#SBATCH --partition=main
#SBATCH --nodes=2                  # Requesting 3 nodes
#SBATCH --ntasks-per-node=1        # 1 MPI rank per node
#SBATCH --gres=gpu:1               # 1 GPU per node
#SBATCH --time=01:00:00
#SBATCH --output=/lambda/nfs/AIML/home/%u/nccl_test.%j.out
#SBATCH --error=/lambda/nfs/AIML/home/%u/nccl_test.%j.err

set -e

# 1. MPI and Library Paths
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# 2. NCCL Settings for Physical Ethernet (eno1)
export NCCL_DEBUG=INFO
export NCCL_SOCKET_IFNAME=eno1
export NCCL_IB_DISABLE=1            # Use TCP instead of InfiniBand
export NCCL_NET=Socket             # Force standard TCP stack
export NCCL_NET_GDR_LEVEL=0

# 3. Generate Host List for mpirun
# This creates the format: node-01:1,node-02:1,node-03:1
HOSTS=$(scontrol show hostnames $SLURM_JOB_NODELIST | awk '{print $1":1"}' | paste -d, -s)

echo "=========================================="
echo "Running Multi-Node NCCL All-Reduce"
echo "Hosts: $HOSTS"
echo "=========================================="

# 4. Execute mpirun
# -n 3: Total number of ranks
# -x: Exports the environment variables to the worker nodes
mpirun -np 2 \
  -H $HOSTS \
  --bind-to none \
  --mca btl_tcp_if_include eno1 \
  --mca oob_tcp_if_include eno1 \
  -x NCCL_DEBUG \
  -x NCCL_SOCKET_IFNAME \
  -x NCCL_IB_DISABLE \
  -x NCCL_NET \
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
