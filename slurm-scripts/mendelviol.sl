#!/bin/bash
# mendelviol.sl 
# this slurm batch script provides a table of mendelian violations for every trio that is present in a vcf. It requires access to a pedigree file that includes all individuals in the vcf - this file can include other individuals as well. 
# suggest rewriting this so that it can be a stand alone script for use on any vcf and ped file - needs arguments for input, ped file, perhaps depth and quality, write the output file to the same directory as the input vcf
# so that it can be used in the Variant Call script, or independently
#SBATCH --job-name	MendelViol
#SBATCH --time		72:00:00
#SBATCH --mem		8G
#SBATCH --cpus-per-task	2
#SBATCH --mail-type FAIL,END
#SBATCH --error		slurm/mendelviol/viol-%j.out
#SBATCH --output	slurm/mendelviol/viol-%j.out

echo "$(date) on $(hostname)"
input=$1
PED=$2
if [ -z ${PROJECT_PATH} ]; then
	if [ ! -z ${input} ]; then
		PROJECT_PATH=$(dirname ${input})
	else 
		echo "No input file was provided."
		exit 1
	fi
fi
if [ -z ${PROJECT} ]; then
	if [ ! -z ${input} ]; then
		PROJECT=$(basename ${input} .vcf.gz)
	else 
		echo "No input file was provided."
		exit 1
	fi
fi

if [ -f ${PROJECT_PATH}/done/mendelviol/${PROJECT}_MendelianViolations.txt.done ]; then
	echo "INFO: Output for ${PROJECT} Mendelian Violations should already be available at ${output}"
else
	scontrol update jobid=${SLURM_JOB_ID} jobname=MendelViol_${PROJECT}
	module purge
	module load GATK4
	cmd="gatk --java-options -Xmx2g FindMendelianViolations -I ${input} -PED ${PED} -O ${PROJECT_PATH}/${PROJECT}_MendelianViolationMetrics.txt -DP 10 -GQ 30"
	echo $cmd
	eval $cmd || exit 1$?
	mkdir -p ${PROJECT_PATH}/done/mendelviol
	touch ${PROJECT_PATH}/done/mendelviol/${PROJECT}_MendelianViolations.txt.done
fi

exit 0
