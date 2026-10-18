# lambda_slurm

A hybrid Slurm cluster for running NCCL and HPL benchmarks and distributed ML workloads:
the controller runs in a VM on my laptop, with NVIDIA GPU worker nodes on Lambda Cloud.


This repo holds the Slurm configuration, job scripts, and benchmark output from
getting that setup working end to end.

## Contents

- `config/` — Slurm configuration (`slurm.conf`, `gres.conf`, `cgroup.conf`, pyxis/enroot plugstack)
- `config/history/` — earlier config iterations kept for reference
- `scripts/` — Slurm batch scripts for NCCL all-reduce, reduce-scatter, and PyTorch DDP
- `results/` — raw job output from benchmark runs
- `RESULTS.md` — HPL benchmark results across A10, A100, and H100 GPUs, comparing RoCE and NVLink

## Setup

- **Controller:** Slurm 26.05.4 in a local VM (`head-slurm`)
- **Workers:** Lambda Cloud NVIDIA GPU instances (A10, A100, H100)
- **Containers:** enroot + pyxis
- **Transports compared:** VPN tunnel, MPI over TCP, and HPC-X with RDMA


## Key result

**The interconnect has to scale with the GPU.** On the same ~30 Gb/s RoCE network,
two A10s scaled at 95.8%, but two A100s were slower together than one A100 alone.
Two H100s over NVLink in one node scaled at 98.9%. Full details: [RESULTS.md](RESULTS.md)


Still a work in progress. I'm using this to learn multi-node GPU communication
and Slurm administration hands-on.

## About this project

I used an AI assistant as a learning and troubleshooting aid while building this lab.
I tested, debugged, and maintain everything here myself.
