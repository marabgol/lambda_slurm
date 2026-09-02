#!/bin/bash
#SBATCH --job-name=nccl_test
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --time=00:30:00
#SBATCH --partition=main        # Partition name (adjust to your cluster)
#SBATCH --output=/lambda/nfs/AIML/home/%u/nccl_test.%j.out  # Output file
#SBATCH --error=/lambda/nfs/AIML/home/%u/nccl_test.%j.err   # Error file
#SBATCH --chdir=/lambda/nfs/AIML/home/majid

# -------------------------
# Environment setup
# -------------------------
# MPI
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# CUDA
export CUDA_HOME=/usr/local/cuda-12.8
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# NCCL
#export NCCL_DEBUG=INFO
export NCCL_SOCKET_IFNAME=wg0
export NCCL_IB_DISABLE=1
export NCCL_NET_GDR_LEVEL=0

# Path to nccl-tests binary
BUILD_DIR=/lambda/nfs/AIML/nccl-tests/build
EXEC=$BUILD_DIR/all_reduce_perf

# Buffer sizes
MIN_BYTES=8388608
MAX_BYTES=536870912
STEP_FACTOR=2
GPUS_PER_RANK=1

# -------------------------
# Run MPI
# -------------------------
mpirun --bind-to none --map-by slot \
       -np $SLURM_NTASKS \
       -H $(scontrol show hostnames $SLURM_JOB_NODELIST | paste -sd ","):1 \
       $EXEC -b 8M -e 256M -f 1 -g 1 -i 5


