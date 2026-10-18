#!/bin/bash
# Usage: [TEST=all_gather] bash ~/ctr-nccl.sh <channels|default>
#   TEST: all_reduce (default), all_gather, reduce_scatter, alltoall, sendrecv, broadcast ...
#   Inside an salloc shell, srun runs as a step of that allocation (no queueing).
CH=${1:-default}
TEST=${TEST:-all_reduce}
IMG=$HOME/images/hpc-benchmarks-26.02.01.sqsh
BIN=$HOME/nccl-tests-ctr/build/${TEST}_perf
LOG=$HOME/nccl-results/ctr-${TEST}-${CH}ch-$(date +%H%M%S).log
[ -x "$BIN" ] || { echo "No such test binary: $BIN"; exit 1; }
export NCCL_DEBUG=INFO NCCL_DEBUG_SUBSYS=INIT,NET,ENV
export NCCL_IB_HCA=mlx5_0 NCCL_IB_GID_INDEX=3 NCCL_SOCKET_IFNAME=eno1
export OMPI_MCA_pmix=s2 UCX_NET_DEVICES=mlx5_0:1
[ "$CH" != default ] && export NCCL_MIN_NCHANNELS=$CH
cd ~
srun -J "nccl-$TEST" -N2 --ntasks-per-node=1 --gres=gpu:1 -c 16 --cpu-bind=none \
  --container-image="$IMG" --container-name=hpc --container-mounts=$HOME:$HOME \
  $BIN -b 8 -e 1G -f 2 -g 1 > "$LOG" 2>&1
echo "=== $TEST, $CH channels -> $LOG"
grep -E "^# +Rank" "$LOG"
grep -m1 "NCCL version" "$LOG"
grep -m1 "coll channels" "$LOG"
grep -m1 "via NET" "$LOG"
grep -m1 "Connected all rings" "$LOG"
grep -E "^ +(536870912|1073741824) " "$LOG"
grep -E "Avg bus bandwidth|rror" "$LOG" | head -3
