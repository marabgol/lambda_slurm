import torch
import torch.distributed as dist
import os
import time
from datetime import timedelta

def run_stress():
    rank = int(os.environ['RANK'])
    world_size = int(os.environ['WORLD_SIZE'])
    local_rank = int(os.environ['LOCAL_RANK'])
    
    torch.cuda.set_device(local_rank)
    device = torch.device(f"cuda:{local_rank}")
    
    # Use eno1 via the environment variables set in Slurm
    dist.init_process_group(backend='nccl', timeout=timedelta(minutes=30))

    if rank == 0:
        print(f"Stress Test: 50G Physical Wire (eno1) | World Size: {world_size}")

    # ~1.6GB tensor
    tensor_a = torch.randn(20480, 20480, device=device) 
    
    iters = 1000  
    start_time = time.time()
    
    for i in range(iters):
        # Compute
        tensor_a = torch.matmul(tensor_a, tensor_a) * 0.01
        # Data
        dist.all_reduce(tensor_a, op=dist.ReduceOp.SUM)
        
        if i % 10 == 0 and rank == 0:
            print(f"Iteration {i}/{iters} complete. Elapsed: {time.time() - start_time:.2f}s")

    dist.barrier()
    dist.destroy_process_group()

if __name__ == "__main__":
    run_stress()
