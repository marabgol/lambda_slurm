#!/bin/bash
#SBATCH --job-name=nccl_vpn_test
#SBATCH --partition=main
#SBATCH --nodes=3                  # You can change this number now
#SBATCH --ntasks-per-node=1        # 1 process per node
#SBATCH --cpus-per-task=4          
#SBATCH --gres=gpu:1               
#SBATCH --time=01:00:00            
#SBATCH --output=/lambda/nfs/AIML/home/%u/nccl_test.%j.out
#SBATCH --error=/lambda/nfs/AIML/home/%u/nccl_test.%j.err

set -e
set -x

# Determine the number of nodes and task list from Slurm
NUM_NODES=$SLURM_JOB_NUM_NODES
# This converts the Slurm node list (e.g. node-[01-02]) into a comma-separated list
HOST_LIST=$(scontrol show hostnames $SLURM_JOB_NODELIST | paste -d, -s)

echo "=========================================="
echo "NCCL Test - Multi-Node GPU Communication"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Nodes Requested: $NUM_NODES"
echo "Nodes Assigned: $HOST_LIST"
echo "Start time: $(date)"
echo ""

# MPI environment
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# NCCL environment
export NCCL_SOCKET_IFNAME=wg0
export NCCL_IB_DISABLE=1
export NCCL_NET_GDR_LEVEL=0
export NCCL_MIN_CHUNK_SIZE=65536
export NCCL_TIMEOUT=500
export NCCL_DEBUG=INFO

echo "=========================================="
echo "Running NCCL All-Reduce Test on $NUM_NODES Nodes"
echo "=========================================="

# -np $NUM_NODES: Uses the variable from Slurm
# --host $HOST_LIST: Automatically uses the nodes Slurm gave you
srun --gres=gpu:1 -n 3 -N 3 \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M -e 2G -f 1.1 -g 1 -n 100 -w 20
echo ""
echo "Test Complete!"
echo "End time: $(date)"
