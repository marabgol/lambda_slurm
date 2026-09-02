#!/bin/bash
#SBATCH --partition=main        # Partition name (adjust to your cluster)
#SBATCH --output=/lambda/nfs/AIML/home/%u/nccl_test.%j.out  # Output file
#SBATCH --error=/lambda/nfs/AIML/home/%u/nccl_test.%j.err   # Error file

#!/bin/bash
#SBATCH --job-name=nccl_vpn_test
#SBATCH --nodes=2                  # Number of nodes
#SBATCH --ntasks-per-node=1        # 1 process per node
#SBATCH --cpus-per-task=4          # Number of CPU cores per MPI rank
#SBATCH --gpus-per-node=1          # 1 GPU per node
#SBATCH --time=01:00:00            # Job runtime (hh:mm:ss)
#SBATCH --chdir=/lambda/nfs/AIML/home/majid

# Load MPI if needed (skip if module system not available)
# module load openmpi/4.1.7

# NCCL and MPI environment
export MPI=1
export MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7rc1
export PATH=$MPI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MPI_HOME/lib:$LD_LIBRARY_PATH

# NCCL environment for VPN
export NCCL_SOCKET_IFNAME=wg0       # Use VPN interface
export NCCL_IB_DISABLE=1            # Disable InfiniBand
export NCCL_NET_GDR_LEVEL=0         # Disable GPU Direct RDMA
export NCCL_MIN_CHUNK_SIZE=65536    # Smaller chunks for slower network
export NCCL_TIMEOUT=500             # Increase timeout for slow network
export NCCL_DEBUG=INFO

# Optional: show GPU usage before starting
nvidia-smi

# Run NCCL test with MPI
mpirun -np 2 \
  -H node-01:1,node-02:1 \
  -x NCCL_SOCKET_IFNAME \
  -x NCCL_IB_DISABLE \
  -x NCCL_NET_GDR_LEVEL \
  -x NCCL_MIN_CHUNK_SIZE \
  -x NCCL_TIMEOUT \
  -x NCCL_DEBUG \
  /lambda/nfs/AIML/nccl-tests/build/all_reduce_perf \
    -b 8M -e 512M -f 2 -g 1

# Optional: show GPU usage after completion
nvidia-smi
