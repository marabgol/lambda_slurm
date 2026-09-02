import torch
import torch.distributed as dist
import os
import socket

def setup():
    # Slurm sets these env vars automatically via srun
    rank = int(os.environ["SLURM_PROCID"])
    world_size = int(os.environ["SLURM_NTASKS"])
    local_rank = int(os.environ["SLURM_LOCALID"])

    # Initialize the process group with NCCL
    dist.init_process_group(backend="nccl")
    
    torch.cuda.set_device(local_rank)
    return rank, world_size

def run_test(rank, world_size):
    # Create a tensor on the GPU
    tensor = torch.ones(1).cuda() * (rank + 1)
    
    print(f"Rank {rank} on {socket.gethostname()} starting All-Reduce. Value: {tensor.item()}")
    
    # Sum all tensors across all nodes
    dist.all_reduce(tensor, op=dist.ReduceOp.SUM)
    
    print(f"Rank {rank} finished All-Reduce. Result: {tensor.item()}")
    # Result should be 1+2 = 3.0 if world_size is 2

if __name__ == "__main__":
    r, ws = setup()
    run_test(r, ws)
    dist.destroy_process_group()
