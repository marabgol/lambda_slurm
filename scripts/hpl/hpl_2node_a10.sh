cd ~/lambda_slurm/scripts/hpl && mkdir -p results
export UCX_NET_DEVICES=mlx5_0:1 UCX_IB_GID_INDEX=3 OMPI_MCA_pmix=s2
export NCCL_IB_HCA=mlx5_0 NCCL_IB_GID_INDEX=3 NCCL_SOCKET_IFNAME=eno1
export NCCL_DEBUG=INFO NCCL_DEBUG_SUBSYS=INIT,NET
# export NCCL_NET_GDR_LEVEL=PHB        # uncomment = the GDR=1 variant
LOG=results/hpl-a10-2node-slurm-$(date +%F-%H%M).log
srun -J hpl -N2 --ntasks-per-node=1 --gres=gpu:1 -c 16 --cpu-bind=none --mpi=pmi2 \
  --container-image=$HOME/images/hpc-benchmarks-26.02.01.sqsh --container-name=hpc \
  --container-mounts=$HOME:$HOME \
  /workspace/hpl.sh --dat $HOME/lambda_slurm/scripts/hpl/inputs/HPL-A10-2GPU-N45056.dat 2>&1 | tee $LOG
grep -E "^W[RC]|PASSED|FAILED" $LOG; grep -E "GPU Direct RDMA|via NET" $LOG | sort -u | head
