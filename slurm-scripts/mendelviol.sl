#!/bin/bash
# mendelviol.sl 
# this script is intended to take a collection of non-overlapping contig vcf.gz files, all with the same individuals in them, and stitch them together into one vcf.gz
#SBATCH --job-name	MendelViol
#SBATCH --time		24:00:00
#SBATCH --mem		4G
#SBATCH --cpus-per-task	1
#SBATCH --mail-type FAIL,END
#SBATCH --error		slurm/mendelviol/viol-%j.out
#SBATCH --output	slurm/mendelviol/viol-%j.out

echo "$(date) on $(hostname)"
source ${PROJECT_PATH}/parameters.sh

if [ -f ${PROJECT_PATH}/done/mendelviol/${PROJECT}_MendelianViolations.txt.done ]; then
	echo "INFO: Output for Mendelian Violations already available"
else
	scontrol update jobid=${SLURM_JOB_ID} jobname=MendelViol_${PROJECT}
	module purge
	module load GATK4
	cmd="gatk --java-options -Xmx2g FindMendelianViolations -I ${PROJECT_PATH}/merge/${PROJECT}.vcf.gz -PED ${PED} -O ${PROJECT_PATH}/${PROJECT}_MendelianViolationMetrics.txt -DP 10 -GQ 30"
	echo $cmd
	eval $cmd || exit 1$?
	mkdir -p ${PROJECT_PATH}/done/mendelviol
	touch ${PROJECT_PATH}/done/mendelviol/${PROJECT}_MendelianViolations.txt.done
fi

exit 0
