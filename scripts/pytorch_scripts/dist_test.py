import torch
import torch.distributed as dist
import os
import socket

def run():
    # Get environment variables set by Slurm/Script
    rank = int(os.environ['RANK'])
    world_size = int(os.environ['WORLD_SIZE'])
    local_rank = int(os.environ['LOCAL_RANK'])
    
    # Set the GPU device
    torch.cuda.set_device(local_rank)
    device = torch.device(f"cuda:{local_rank}")

    print(f"Rank {rank}/{world_size} starting on {socket.gethostname()} (GPU {local_rank})")

    # Initialize the process group using NCCL
    dist.init_process_group(backend='nccl')

    # Create a dummy tensor on GPU
    tensor = torch.ones(1024, 1024, 10, device=device) * (rank + 1)
    print(f"Rank {rank}: Tensor sum before All-Reduce: {tensor.sum().item()}")

    # Perform All-Reduce (Sum)
    dist.all_reduce(tensor, op=dist.ReduceOp.SUM)

    print(f"Rank {rank}: All-Reduce complete. Result sum: {tensor.sum().item()}")
    
    if rank == 0:
        print("SUCCESS: All nodes have communicated!")

if __name__ == "__main__":
    run()
