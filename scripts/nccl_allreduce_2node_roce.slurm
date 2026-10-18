#!/bin/bash
#SBATCH --job-name=nccl_roce_2node
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --chdir=/lambda/nfs/AIML/home/majid
#SBATCH --output=/lambda/nfs/AIML/home/majid/nccl_roce_2node.%j.out

echo "Nodes: $SLURM_JOB_NODELIST   memlock: $(ulimit -l)"

# MPI only launches the ranks (control traffic over the VPN, wg0).
# NCCL moves the GPU data over RoCE: mlx5_0, GID 3 = RoCE v2 over IPv4.
mpirun -np $SLURM_NTASKS --map-by ppr:1:node --bind-to none \
  --mca oob_tcp_if_include wg0 \
  --mca btl_tcp_if_include wg0 \
  -x NCCL_IB_HCA=mlx5_0:1 \
  -x NCCL_IB_GID_INDEX=3 \
  -x NCCL_SOCKET_IFNAME=eno1 \
  -x NCCL_DEBUG=INFO \
  -x NCCL_DEBUG_SUBSYS=INIT,NET \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8 -e 1G -f 2 -g 1 -n 20 -w 5
