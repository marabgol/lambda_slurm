# Results

All runs: NVIDIA HPL (HPL-NVIDIA 26.2.0, container `nvcr.io/nvidia/hpc-benchmarks:26.02`),
NB = 1024, all residual checks **PASSED**. Lambda Cloud on-demand instances, October 2026.

## Summary

**The interconnect has to scale with the GPU.**

| GPUs | Interconnect | Per-GPU HPL | 2-GPU efficiency |
|---|---|---|---|
| 2× A10, two nodes | RoCE v2, ~30 Gb/s delivered (~3.75 GB/s) | 0.42 TFLOPS | **95.8%**  |
| 2× A100 40GB, two nodes | same RoCE network | 16.1 TFLOPS | **25.5%** , **36.4%**  |
| 2× H100 80GB, one node | NVLink 4, NV18 (~450 GB/s per direction) | 47.2 TFLOPS | **98.9%**  |

On the same ~30 Gb/s RoCE network, two A10s scaled almost perfectly, but two A100s were slower together than one
A100 alone: the A10's low FP64 throughput hid the communication time, while the A100 (~39× faster) exposed it.
Two H100s (another ~3× faster) scaled at 98.9% because NVLink is roughly 125× faster than that network.

## Single GPU

| GPU | N | Time (s) | Gflops | % of peak | GPU memory used | Power / clock during solve |
|---|---|---|---|---|---|---|
| A10 | 40,960 | 110.28 | 415.5 | 85% | 19,111 MiB | ~85–92 W / 1695 MHz |
| A10 | 45,056 | 146.55 | 416.1 | 85% | 21,790 MiB (97%) | ~90 W / 1695 MHz |
| A100 40GB SXM4 | 45,056 | 4.02 | 15,170 | 78% | — | — |
| A100 40GB SXM4 | 61,440 | 9.59 | 16,130 | 83% (87% at actual clock) | 35.5 GiB | 396 W / 1335 MHz (power-limited) |
| H100 80GB HBM3 (SXM5) | 92,160 | 11.05 | 47,230 | 70% of nominal peak | — | not recorded (700 W limit) |

Peak values used: A10 FP64 ≈ 487 Gflops (1/64 of 31.2 TFLOPS FP32); A100 FP64 Tensor Core = 19.5 TFLOPS at 1410 MHz
(≈ 18.5 TFLOPS at the 1335 MHz the GPU actually ran under its 400 W limit); H100 SXM5 FP64 Tensor Core ≈ 67 TFLOPS at
1980 MHz. The H100 most likely ran below 1980 MHz under its 700 W limit, so its efficiency at the actual clock is
higher than 70%; clocks were not logged for that run.

Relative speed: A100 ≈ 39× A10; H100 ≈ 2.9× A100 ≈ 114× A10.

Observations:
- A10 HPL (415.5 Gflops) essentially equals the DGEMM component test (415.16 Gflops): HPL runs at the GPU's DGEMM limit.
- A10: 100% GPU-Util at only ~90 W of 150 W. GPU-Util measures *time a kernel is running*, not how much of the chip is busy;
  the A10's FP64 units are a small part of the chip. `nvidia-smi dmon`: sm 100%, mem 3% → HPL is compute-bound.
- A100: power at the 400 W limit, clock reduced from 1410 to ~1335 MHz (power throttling).
- Larger N improves efficiency: the slow "tail" at the end of the solve (small remaining matrix) is a smaller share of the run.

## Two nodes over RoCE (1 GPU per node, P × Q = 1 × 2)

| GPUs | N | Scaling | GPUDirect RDMA | Time (s) | Total Gflops | Per GPU | Efficiency vs 1 GPU |
|---|---|---|---|---|---|---|---|
| 2× A10 | 45,056 | strong | not checked (default; likely disabled) | 76.46 | 797.5 | 398.8 | **95.8%** (1.92× speedup) |
| 2× A100 | 61,440 | strong | disabled (NCCL default) | 19.48 | 7,937 | 3,968 | **24.6%** |
| 2× A100 | 61,440 | strong | forced (`NCCL_NET_GDR_LEVEL=PHB`) | 18.80 | 8,227 | 4,113 | 25.5% |
| 2× A100 | 86,016 | weak | forced | 36.14 | 11,740 | 5,870 | 36.4% |

Total wall time (including container start and component tests) for the A100 runs: 71–96 s, vs. 19–36 s of solve time.

Observations:
- **A10:** loss concentrated at the end of the run: `iGF` fell from ~805 to 154–330 in the last steps, when the remaining
  matrix is too small to hide network time.
- **A100:** during communication, nvtop showed 100% GPU-Util but only **104 W** at full 1410 MHz: NCCL kernels spin
  on the GPU while waiting for data, so utilization looks full while almost no math is done.
- **GPUDirect RDMA:** NCCL disabled it by default (`GPU Direct RDMA Disabled ... (distance 8 > 6)`) because GPU and NIC
  are connected through the PCIe host bridge (PHB in `nvidia-smi topo -m`). Forcing it (log shows `via NET/IBext_v11/0/GDRDMA`)
  gained ~3.6%, within run-to-run network variation. The bottleneck was link bandwidth, not host staging.
- **Weak scaling** (larger N) raised per-GPU performance 43% (4.11 → 5.87 TFLOPS): computation grows as N³,
  communication as N², so bigger problems hide the network better. Even so, 2× A100 (11.7 TFLOPS) < 1× A100 (16.1 TFLOPS).
- Rough estimate: HPL broadcasts ~4·N² bytes in panels (~15 GB at N = 61,440). At ~4 GB/s that alone is ~4 s,
  comparable to the ~5 s of compute per GPU, so it cannot be hidden.

## Two GPUs in one node over NVLink (2× H100 80GB HBM3)

Instance: 2× H100 SXM5 (a partition of an HGX H100 server), 700 W limit, 1980 MHz max SM clock, 52 vCPUs in NUMA 0.

```
        GPU0    GPU1    NIC0    CPU Affinity
GPU0     X      NV18    PHB     0-51
GPU1    NV18     X      PHB     0-51
```

`nvidia-smi nvlink -s`: 18 active links per GPU at 26.562 GB/s each (raw rate; NVLink 4 is 25 GB/s per direction per
link → ~450 GB/s per direction, ~900 GB/s bidirectional).

NVIDIA's sample inputs from the container (`/workspace/hpl-linux-x86_64/sample-dat/HPL-1GPU.dat`, `HPL-2GPUs.dat`):

| Run | Runtime | N | P × Q | Time (s) | Total TFLOPS | Per GPU | Residual |
|---|---|---|---|---|---|---|---|
| 1 GPU | Docker | 92,160 | 1 × 1 | 11.05 | 47.23 | 47.23 | 0.000937720526 |
| 2 GPUs (weak) | Docker | 136,192 | 2 × 1 | 18.02 | 93.47 | 46.73 | 0.000263094958 |
| 2 GPUs (weak) | Apptainer | 136,192 | 2 × 1 | 18.05 | 93.32 | 46.66 | 0.000263094958 |

Observations:
- **Weak scaling efficiency 98.9%** (46.73 / 47.23). Each GPU held ~69 GiB of matrix vs. ~63 GiB in the 1-GPU run;
  ideal time 11.05 s × 1.61 (work per GPU) ≈ 17.8 s, measured 18.02 s.
- Even at the end of the run (99.91% progress) the pair still ran at ~34,000 Gflops, where the A100s over RoCE had
  dropped to ~200 Gflops.
- **NCCL transport:** `via P2P/CUMEM` (direct GPU-to-GPU over NVLink, memory shared via CUDA's `cuMem*` API), no NET/SHM.
  **24 channels**; 96 log lines = 24 channels × 2 directions × 2 communicators.
- The NIC is not used for GPU-to-GPU traffic within the node (MPI/UCX uses shared memory / `cuda_ipc`, NCCL uses P2P).
- **Docker vs. Apptainer:** 0.16% apart (run-to-run noise) and an **identical residual to every digit**: same software,
  same deterministic matrix, same operations.

## Network characterization (RoCE v2, mlx5_0, 50 Gb/s "2X EDR")

Settings: MTU 9000 → RDMA active_mtu 4096; GID index 3; `ib_write_bw` 64 KB messages.

| Node pair | Ping (avg) | QPs | Bandwidth (Gb/s) | Loss events (receiver `out_of_sequence`) |
|---|---|---|---|---|
| A10 pair 1 | 0.33 ms | 16 | 25.9, 26.2, 33.8 | +36,671 in 20 s (~1 per 560 packets) |
| A10 pair 1 | | 4 | 17.0 | +24,014 in 20 s (~1 per 430 packets) |
| A10 pair 2 | 0.52 ms | 16 | 31.1 | not measured |
| A100 pair | 0.25 ms | 16 | 32.9 | not measured |
| Earlier A10-type pair (Sept 26) | 0.24 ms | 16 | 48.4 (97% of line rate) | — |

Observations:
- Link reports 50 Gb/s, but today's pairs delivered 26–34 Gb/s.
- Loss confirmed on both sides: sender `packet_seq_err` = 101,059 vs. receiver `out_of_sequence` = 101,377 (0.3% apart).
  Losses only in the data direction (sender's `out_of_sequence` = 0, receiver's `packet_seq_err` = 0).
- Fewer QPs (4) did **not** reduce the loss rate → loss is not caused by our own bursts; likely shared-network congestion
  or provider policing (possibly nodes in different racks). Cannot be confirmed from inside the VMs.
- Per-flow limit: one QP cannot fill the link; ~16 parallel QPs needed (why NCCL opens multiple QPs per connection).
- RDMA traffic is invisible to kernel tools (iftop, nload); measure with NIC counters (`ethtool -S eno1 | grep rdma`).

## Topology

Both A10 and A100 single-GPU instances (KVM VMs) show (verified with `nvidia-smi topo -m` on both types):

```
        GPU0    NIC0    CPU Affinity    NUMA Affinity
GPU0     X      PHB     0-29            0
NIC0    PHB      X
NIC0: mlx5_0
```

A100 SXM4 in a 1-GPU VM: `nvidia-smi nvlink -s` → "all links are inActive" (no NVLink peers in the VM).
The 2× H100 instance: GPUs connected by NV18; NIC at PHB from both GPUs.

