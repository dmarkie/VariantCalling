#!/bin/bash
#genotypegvcf.sl - for joint genotyping gvcf files for contigs

#SBATCH --job-name	GenotypeGVCFs
#SBATCH --time		10-00:00:00
#SBATCH --cpus-per-task	1
#SBATCH --mem		10G
#SBATCH --mail-type FAIL,END
#SBATCH --error		slurm/genotype/ggvcf-%A_%a.out
#SBATCH --output	slurm/genotype/ggvcf-%A_%a.out

echo "$(date) on $(hostname)"

source ${PROJECT_PATH}/parameters.sh

CONTIG=${CONTIGARRAY[$(( ${SLURM_ARRAY_TASK_ID} - 1 ))]}

if [ "${CONTIG}" == "" ]; then
	echo "FAIL: Invalid contig defined at ${SLURM_ARRAY_TASK_ID}"
	exit 1
fi

module purge
module load GATK4

if [ -f ${PROJECT_PATH}/done/genotype/${CONTIG}_gen.vcf.gz.done ]; then
	echo "INFO: Output ${CONTIG}_raw.vcf.gz already completed."
else
	scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=GenotypeGVCF_${PROJECT}_${CONTIG}
	mkdir -p ${PROJECT_PATH}/genotype
	cmd="srun gatk --java-options -Xmx4g \
		GenotypeGVCFs \
		-R ${REFA} \
		-L ${CONTIG} \
		-V gendb:///${PROJECT_PATH}/GenomeDB/${CONTIG} \
		-D $DBSNP \
		-G StandardAnnotation \
		-G AS_StandardAnnotation \
		-ped ${PED} \
		-new-qual \
		-O ${PROJECT_PATH}/genotype/${CONTIG}_gen.vcf.gz"
	echo $cmd
	eval $cmd || exit 1$?
	mkdir -p ${PROJECT_PATH}/done/genotype
	touch ${PROJECT_PATH}/done/genotype/${CONTIG}_gen.vcf.gz.done
	if [ -d ${PROJECT_PATH}/GenomeDB/${CONTIG} ]; then
		rm -r ${PROJECT_PATH}/GenomeDB/${CONTIG}
	fi
fi
exit 0

