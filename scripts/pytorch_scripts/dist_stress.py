import torch
import torch.distributed as dist
import os
import time

def run_stress():
    # Setup IDs
    rank = int(os.environ['RANK'])
    world_size = int(os.environ['WORLD_SIZE'])
    local_rank = int(os.environ['LOCAL_RANK'])
    
    torch.cuda.set_device(local_rank)
    device = torch.device(f"cuda:{local_rank}")
    
    print(f"Rank {rank} starting stress test on GPU {local_rank}...")
    dist.init_process_group(backend='nccl')

    # 1. Memory Stress: Allocate large tensors (approx 8GB total usage)
    # A 32768 x 16384 float32 tensor is ~2GB. 
    # With NCCL buffers and temporary math tensors, this will use significantly more.
    tensor_a = torch.randn(20480, 20480, device=device) 
    
    iters = 1000  # Number of loops
    print(f"Rank {rank}: Starting {iters} iterations of Compute + All-Reduce...")

    start_time = time.time()
    
    for i in range(iters):
        # 2. Compute Stress: Matrix Multiplication
        # This pushes the GPU cores and Power usage up
        tensor_a = torch.matmul(tensor_a, tensor_a)
        
        # 3. Network Stress: All-Reduce
        # This pushes the 50G wire
        dist.all_reduce(tensor_a, op=dist.ReduceOp.SUM)
        
        if i % 50 == 0:
            elapsed = time.time() - start_time
            print(f"Rank {rank}: Iteration {i}/{iters} complete. Total elapsed: {elapsed:.2f}s")

    dist.destroy_process_group()
    print(f"Rank {rank}: Stress Test Finished in {time.time() - start_time:.2f}s")

if __name__ == "__main__":
    run_stress()
