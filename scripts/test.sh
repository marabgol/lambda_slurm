#!/bin/bash
#SBATCH --job-name=test           # Job name
#SBATCH --output=/home/%u/gpu_out_%j.log # Output file in home dir (%u=user, %j=jobID)
#SBATCH --error=/home/%u/gpu_err_%j.log  # Error file in home dir
##SBATCH --partition=gpu               # Name of the GPU partition (check your cluster)
##SBATCH --partition=main               # Name of the GPU partition (check your cluster)
##SBATCH --gres=gpu:1                  # Request 1 GPU
#SBATCH --ntasks=1                    # Run a single task
#SBATCH --time=00:01:00               # Time limit (1 minute)

# Execute the command
hostname

