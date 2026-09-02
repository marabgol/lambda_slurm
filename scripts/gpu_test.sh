#!/bin/bash
#SBATCH --job-name=gpu_test
#SBATCH --output=gpu_test_%j.out
#SBATCH --error=gpu_test_%j.err
#SBATCH --gres=gpu:1
#SBATCH --time=00:05:00

echo "=========================================="
echo "GPU Test Job"
echo "=========================================="
echo ""
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "GPUs allocated: $CUDA_VISIBLE_DEVICES"
echo ""
echo "=========================================="
echo "nvidia-smi output:"
echo "=========================================="
nvidia-smi
echo ""
echo "=========================================="
echo "GPU Memory Info:"
echo "=========================================="
nvidia-smi --query-gpu=name,memory.total,memory.free,memory.used --format=csv
echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
