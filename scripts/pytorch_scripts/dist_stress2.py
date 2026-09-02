import torch
import torch.distributed as dist
import os
import time

def run_stress():
    # Setup IDs from environment
    rank = int(os.environ['RANK'])
    world_size = int(os.environ['WORLD_SIZE'])
    local_rank = int(os.environ['LOCAL_RANK'])
    
    torch.cuda.set_device(local_rank)
    device = torch.device(f"cuda:{local_rank}")
    
    # Initialize the process group
    # We increase the timeout because VPNs are slow
    dist.init_process_group(backend='nccl', timeout=torch.timedelta(minutes=30))

    if rank == 0:
        print(f"Stress Test starting with {world_size} ranks...")

    # Create large tensors (~1.6GB each)
    # Matmul will create a 3rd temporary tensor, using ~5GB VRAM
    tensor_a = torch.randn(20480, 20480, device=device) 
    
    iters = 500 
    for i in range(iters):
        # Compute stress
        tensor_a = torch.matmul(tensor_a, tensor_a)
        
        # Network stress (RoCE eno1)
        dist.all_reduce(tensor_a, op=dist.ReduceOp.SUM)
        
        if i % 10 == 0 and rank == 0:
            print(f"Iteration {i}/{iters} complete...")

    # CRITICAL: Force all nodes to reach this point before exiting
    print(f"Rank {rank} reached barrier. Waiting for others...")
    dist.barrier() 

    if rank == 0:
        print("Stress Test Finished successfully.")
    
    dist.destroy_process_group()

if __name__ == "__main__":
    run_stress()
