#!/bin/bash
#SBATCH --job-name=nccl_reduce_scatter
#SBATCH --output=nccl_reduce_scatter_%j.out
#SBATCH --error=nccl_reduce_scatter_%j.err
#SBATCH --nodes=2                    # Use both worker nodes
#SBATCH --ntasks=2                   # 2 tasks total (1 per node)
#SBATCH --ntasks-per-node=1          # 1 task per node
#SBATCH --cpus-per-task=8            # 8 CPUs per GPU
#SBATCH --gres=gpu:a10:1             # 1 A10 GPU per node
#SBATCH --time=00:30:00              # 30 minutes
#SBATCH --partition=main

###############################################################################
# NCCL Multi-Node GPU Performance Test
# Tests: reduce_scatter collective operation across 2 nodes with 2 A10 GPUs
###############################################################################

echo "=========================================="
echo "NCCL Reduce Scatter Performance Test"
echo "=========================================="
echo ""
echo "Job ID: $SLURM_JOB_ID"
echo "Job Name: $SLURM_JOB_NAME"
echo "Nodes: $SLURM_JOB_NODELIST"
echo "Number of Nodes: $SLURM_JOB_NUM_NODES"
echo "Number of Tasks: $SLURM_NTASKS"
echo "CPUs per task: $SLURM_CPUS_PER_TASK"
echo "GPUs allocated: $CUDA_VISIBLE_DEVICES"
echo ""

# Print node information
echo "=========================================="
echo "Node Information"
echo "=========================================="
srun --ntasks=$SLURM_NTASKS bash -c 'echo "Task $SLURM_PROCID on $(hostname): GPU $CUDA_VISIBLE_DEVICES"'
echo ""

# Set NCCL environment variables for optimal performance
export NCCL_DEBUG=INFO               # Set to INFO for detailed output, WARN for less verbose
export NCCL_DEBUG_SUBSYS=ALL         # Debug all NCCL subsystems
export NCCL_IB_DISABLE=1             # Disable InfiniBand (not using IB)
export NCCL_SOCKET_IFNAME=wg0        # Use WireGuard interface for communication
export NCCL_P2P_LEVEL=SYS            # Enable system-level P2P

# NCCL network optimization
export NCCL_NET_GDR_LEVEL=0          # Disable GPU Direct RDMA (not supported over WireGuard)
export NCCL_BUFFSIZE=8388608         # 8MB buffer size
export NCCL_NTHREADS=640             # Number of NCCL threads

# Print NCCL environment
echo "=========================================="
echo "NCCL Environment"
echo "=========================================="
echo "NCCL_DEBUG: $NCCL_DEBUG"
echo "NCCL_SOCKET_IFNAME: $NCCL_SOCKET_IFNAME"
echo "NCCL_IB_DISABLE: $NCCL_IB_DISABLE"
echo ""

# Verify GPU visibility on each node
echo "=========================================="
echo "GPU Verification"
echo "=========================================="
srun --ntasks=$SLURM_NTASKS nvidia-smi --query-gpu=gpu_name,memory.total,driver_version --format=csv
echo ""

# Path to NCCL test binary
NCCL_TEST_BIN="/lambda/nfs/AIML/nccl-tests/build/reduce_scatter_perf"

if [ ! -f "$NCCL_TEST_BIN" ]; then
    echo "ERROR: NCCL test binary not found at $NCCL_TEST_BIN"
    exit 1
fi

echo "=========================================="
echo "Running NCCL Reduce Scatter Test"
echo "=========================================="
echo "Binary: $NCCL_TEST_BIN"
echo ""

# Run NCCL test across all allocated GPUs
# -b: beginning size (8 bytes)
# -e: ending size (1GB)
# -f: multiplication factor (2)
# -g: GPUs per process (1)
# -c: check correctness (1 = enable)

srun --ntasks=$SLURM_NTASKS \
     --ntasks-per-node=1 \
     --cpus-per-task=$SLURM_CPUS_PER_TASK \
     "$NCCL_TEST_BIN" \
     -b 8 \
     -e 1G \
     -f 2 \
     -g 1 \
     -c 1

EXIT_CODE=$?

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
echo "Exit code: $EXIT_CODE"
echo "Job ID: $SLURM_JOB_ID"
echo "Output file: nccl_reduce_scatter_${SLURM_JOB_ID}.out"
echo "Error file: nccl_reduce_scatter_${SLURM_JOB_ID}.err"
echo "=========================================="

exit $EXIT_CODE

