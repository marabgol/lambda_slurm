# Test environment (2026-10-18)

- Cluster: Slurm 26.05.4, head node in a local VM, 2 GPU workers on Lambda Cloud
- Workers: 1x NVIDIA A10 each, ConnectX (mlx5_0) RoCE v2, link 50 Gb/s, GID index 3
- Container: nvcr.io/nvidia/hpc-benchmarks:26.02.01 via Pyxis/Enroot
- NCCL: 2.29.2+cuda13.1 (from the container), net plugin IBext_v11
- nccl-tests: built inside the container (~/nccl-tests-ctr)
- GPUDirect RDMA: available, not used (GPU and NIC at PHB distance, "GDR 0")
- Launch: srun --mpi=pmi2 (OMPI_MCA_pmix=s2), 1 rank per node, -c 16

| Test | Channels | Bus bandwidth at 1 GB |
|---|---|---|
| all_reduce | default (2) | 1.09 GB/s |
| all_reduce | 16 | 2.77 GB/s |
