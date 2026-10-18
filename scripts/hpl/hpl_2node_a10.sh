#!/bin/bash
# HPL on 2x A10 (1 GPU per node) over RoCE, NVIDIA HPC benchmarks container via Pyxis.
# Run from a node where $HOME is the shared file system (the workers in this lab).
#   bash hpl_2node_a10.sh [input.dat]
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
DAT=${1:-$HERE/inputs/HPL-A10-2GPU-N45056.dat}
IMG=$HOME/images/hpc-benchmarks-26.02.01.sqsh
mkdir -p "$HERE/results"
LOG=$HERE/results/hpl-a10-2node-$(date +%F-%H%M).log

export UCX_NET_DEVICES=mlx5_0:1 UCX_IB_GID_INDEX=3 OMPI_MCA_pmix=s2
export NCCL_IB_HCA=mlx5_0 NCCL_IB_GID_INDEX=3 NCCL_SOCKET_IFNAME=eno1
export NCCL_DEBUG=INFO NCCL_DEBUG_SUBSYS=INIT,NET
# export NCCL_NET_GDR_LEVEL=PHB        # uncomment = the GDR=1 variant

srun -J hpl -N2 --ntasks-per-node=1 --gres=gpu:1 -c 16 --cpu-bind=none --mpi=pmi2 \
  --container-image="$IMG" --container-name=hpc \
  --container-mounts=$HOME:$HOME \
  /workspace/hpl.sh --dat "$DAT" 2>&1 | tee "$LOG"

echo "=== $LOG"
grep -E "^W[RC]|PASSED|FAILED" "$LOG"
grep -E "GPU Direct RDMA|via NET" "$LOG" | sort -u | head
