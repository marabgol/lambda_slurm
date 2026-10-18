# lambda_slurm

A hybrid Slurm cluster for running NCCL benchmarks and distributed ML workloads:
the controller runs in a VM on my laptop, with NVIDIA GPU worker nodes on Lambda Cloud.

This repo holds the Slurm configuration, job scripts, and benchmark output from
getting that setup working end to end.

## Contents

- `config/` — Slurm configuration (`slurm.conf`, `gres.conf`, `cgroup.conf`, pyxis/enroot plugstack)
- `config/history/` — earlier config iterations kept for reference
- `scripts/` — Slurm batch scripts for NCCL all-reduce, reduce-scatter, and PyTorch DDP
- `results/` — raw job output from benchmark runs

## Setup

- **Controller:** Slurm 26.05.4 in a local VM (`head-slurm`)
- **Workers:** Lambda Cloud NVIDIA GPU instances (A10)
- **Containers:** enroot + pyxis
- **Transports compared:** VPN tunnel, MPI over TCP, and HPC-X with RDMA

Still a work in progress. I'm using this to learn multi-node GPU communication
and Slurm administration hands-on.

## About this project

I used an AI assistant as a learning and troubleshooting aid while building this lab.
I tested, debugged, and maintain everything here myself.
