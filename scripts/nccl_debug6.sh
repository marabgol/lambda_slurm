#!/bin/bash
#SBATCH --job-name=nccl_mpi_test
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --partition=main
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_mpi_%j.out
#SBATCH --error=/lambda/nfs/AIML/home/majid/nccl_mpi_%j.err

# 1. Environment variables for NCCL
export NCCL_DEBUG=INFO
export NCCL_SOCKET_IFNAME=wg0
export NCCL_IB_DISABLE=1
export NCCL_NET=Socket
export NCCL_P2P_DISABLE=1

# 2. Path to your MPI and Binary
MPI_BIN="/usr/mpi/gcc/openmpi-4.1.7rc1/bin/mpirun"
NCCL_TEST_BIN="/lambda/nfs/AIML/nccl-tests/build/reduce_scatter_perf"

# 3. Create a hostfile from Slurm (MPI needs to know the node names)
scontrol show hostnames $SLURM_JOB_NODELIST > hostfile

echo "Launching with MPI..."

# 4. Run with mpirun
# -np 2: Run 2 processes
# -hostfile: Use the nodes Slurm gave us
# -mca btl_tcp_if_include wg0: Tell MPI itself to use WireGuard
# -x: Export our NCCL variables to the worker nodes
$MPI_BIN -np 2 \
    --hostfile hostfile \
    --mca btl_tcp_if_include wg0 \
    -x NCCL_DEBUG \
    -x NCCL_SOCKET_IFNAME \
    -x NCCL_IB_DISABLE \
    -x NCCL_NET \
    -x NCCL_P2P_DISABLE \
    $NCCL_TEST_BIN -b 8 -e 128M -f 2 -g 1 -c 1
