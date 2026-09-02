import torch
import torch.distributed as dist
import os
import time
from datetime import timedelta  # <--- Correct import

def run_stress():
    # Setup IDs
    rank = int(os.environ['RANK'])
    world_size = int(os.environ['WORLD_SIZE'])
    local_rank = int(os.environ['LOCAL_RANK'])
    
    torch.cuda.set_device(local_rank)
    device = torch.device(f"cuda:{local_rank}")
    
    # Initialize with the correct timedelta object
    dist.init_process_group(backend='nccl', timeout=timedelta(minutes=30))

    if rank == 0:
        print(f"Stress Test starting on {world_size} ranks via RoCE...")

    # Create a large tensor (~1.6GB). 
    # Matmul will use ~5GB+ VRAM during the operation
    tensor_a = torch.randn(20480, 20480, device=device) 
    
    iters = 1000  
    start_time = time.time()
    
    for i in range(iters):
        # 1. GPU CORE STRESS
        # We use a small multiplier to keep numbers from exploding to infinity
        tensor_a = torch.matmul(tensor_a, tensor_a) * 0.01
        
        # 2. NETWORK STRESS (All-Reduce over 50G wire)
        dist.all_reduce(tensor_a, op=dist.ReduceOp.SUM)
        
        if i % 10 == 0 and rank == 0:
            elapsed = time.time() - start_time
            print(f"Iteration {i}/{iters} complete. Elapsed: {elapsed:.2f}s")

    dist.barrier()
    if rank == 0:
        print(f"SUCCESS: Stress test finished in {time.time() - start_time:.2f}s")
    
    dist.destroy_process_group()

if __name__ == "__main__":
    run_stress()
