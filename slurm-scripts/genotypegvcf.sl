#!/bin/bash
#genotypegvcf.sl - for joint genotyping gvcf files for contigs

#SBATCH --job-name	GenotypeGVCFs
#SBATCH --time		10-00:00:00
#SBATCH --cpus-per-task	2
#SBATCH --mem		10G
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
# The amount of temporary disk storage required by GenomicsDBImport may exceed what is available in the default location: `/tmp`.
# The command line argument `--tmp-dir` can be used to specify an alternate temporary storage location with sufficient space.

if [ -f ${PROJECT_PATH}/done/genotype/${CONTIG}_raw.vcf.gz.done ]; then
	echo "INFO: Output ${CONTIG}_raw.vcf.gz already completed."
else
	scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=GenotypeGVCF_${PROJECT}_${CONTIG}
	mkdir -p ${PROJECT_PATH}/genotype
	# --allow-old-rms-mapping-quality-annotation-data ### this may need to be added so that GATK v4.1.3 will process alignments done with older versions of GATK - these use a RAW_MQ score which is no longer natively recognised by 4.1.3
	#-G StandardAnnotation \ this annotation group is enabled for this tool by default and is not necessary to specify
	cmd="srun gatk --java-options -Xmx4g \
		GenotypeGVCFs \
		-R ${REFA} \
		-L ${CONTIG} \
		-V gendb:///${PROJECT_PATH}/GenomeDB/GenomeDB_${CONTIG} \
		-D $DBSNP \
		-G AS_StandardAnnotation \
		-ped ${PED} \
		--tmp-dir ${TMPDIR} \
		-O ${PROJECT_PATH}/genotype/${CONTIG}_raw.vcf.gz"
	echo $cmd
	eval $cmd || exit 1$?
	mkdir -p ${PROJECT_PATH}/done/genotype
	touch ${PROJECT_PATH}/done/genotype/${CONTIG}_raw.vcf.gz.done
	if [ -d ${PROJECT_PATH}/GenomeDB/GenomeDB_${CONTIG} ]; then
		rm -r ${PROJECT_PATH}/GenomeDB/GenomeDB_${CONTIG}
	fi
fi


if [ -f ${PROJECT_PATH}/done/genotype/${CONTIG}_gen.vcf.gz.done ]; then
	echo "INFO: Output from normalising contig ${CONTIG} already available"
else
	scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=Normalise_${PROJECT}_${CONTIG}
	module purge
	module load BCFtools
	cmd="$(which bcftools) norm -f ${REFA} ${PROJECT_PATH}/genotype/${CONTIG}_raw.vcf.gz -Oz -o ${PROJECT_PATH}/genotype/${CONTIG}_gen.vcf.gz"
	echo $cmd
	eval $cmd || exit 1$?
	touch ${PROJECT_PATH}/done/genotype/${CONTIG}_gen.vcf.gz.done
fi

if [ -f ${PROJECT_PATH}/done/genotype/${CONTIG}_gen.vcf.gz.tbi.done ]; then
	echo "INFO: Index from normalising contig ${CONTIG} already available"
else
	scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=IndexNorm_${PROJECT}_${CONTIG}
	module purge
	module load BCFtools
	cmd="$(which bcftools) index -t ${PROJECT_PATH}/genotype/${CONTIG}_gen.vcf.gz"
	echo $cmd
	eval $cmd || exit 1$?
	touch ${PROJECT_PATH}/done/genotype/${CONTIG}_gen.vcf.gz.tbi.done
fi

exit 0

