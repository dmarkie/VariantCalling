#!/bin/bash
#recalvcf.sl - for variant recalibration
#SBATCH --job-name	RecalibrateVCFs
#SBATCH --time		4:00:00
#SBATCH --mem		20G
#SBATCH --array		1-2
#SBATCH --cpus-per-task	2
#SBATCH --error 	slurm/recalibrate/recal-%A_%a.out
#SBATCH --output	slurm/recalibrate/recal-%A_%a.out

echo "$(date) on $(hostname)"

source ${PROJECT_PATH}/parameters.sh
# sort out MODE (SNP or INDEL) and set appropriate configurations for each
MODEARRAY=(SNP INDEL)
MODE=${MODEARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo "${MODE} Recalibration"
# check if job already done
if [ -e ${PROJECT_PATH}/done/recalibrate/${MODE}output.recal.done ]; then
	echo "INFO: Output for ${MODE} VariantRecalibrator already available"
	exit 0
fi
if [ $MODE == "SNP" ]; then
# need to use appropriate resource files, appropriate priors, appropriate known, training and truth
	resources="-resource:hapmap,known=false,training=true,truth=true,prior=15.0 ${hapmapversion} -resource:omni,known=false,training=true,truth=true,prior=12.0 ${omniversion} -resource:1000G,known=false,training=true,truth=false,prior=10.0 ${KGversion} -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 ${DBSNP}"
#	resources="-resource hapmap,known=false,training=true,truth=true,prior=15.0:${hapmapversion} -resource omni,known=false,training=true,truth=true,prior=12.0:${omniversion} -resource 1000G,known=false,training=true,truth=false,prior=10.0:${KGversion} -resource dbsnp,known=true,training=false,truth=false,prior=2.0:${DBSNP}"
# need to choose appropriate annotations to use for snps with and without capture
	if [ $capture == yes ]; then
		annotations="-an QD -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR" # -an InbreedingCoeff
	elif [ $capture == no ]; then
		annotations="-an QD -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR" #  the MQ annotation has been causing the failure of recalibration, -an MQ  -an InbreedingCoeff
	fi
	#need to use appropriate tranches
	tranches="-tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0"
	#default max gaussians is 8 - if small number of samples (ie limited number of variants) then reduce eg 4
#	maxgaus="--max-gaussians 4"
elif [ $MODE == "INDEL" ]; then
	#need to use appropriate resource files, appropriate priors, appropriate known, training and truth
	resources="-resource:mills,known=false,training=true,truth=true,prior=12.0 ${millsversion} -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 ${DBSNP}"
#	resources="-resource mills,known=false,training=true,truth=true,prior=12.0:${millsversion} -resource dbsnp,known=true,training=false,truth=false,prior=2.0:${DBSNP}"
	#need to use appropriate annotations to use for indels
	annotations="-an QD -an DP -an FS -an SOR -an ReadPosRankSum -an MQRankSum" # -an InbreedingCoeff
	#need to use appropriate tranches
	tranches="-tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0"
	# appropriate for indels
	maxgaus="--max-gaussians 4"
fi
echo "Resources: $resources"

# decide whether using allele specific annotation or not
if [ $allelespecific == "yes" ]; then AS="-AS"; fi
# construct interval statements to use if these are specified
if [ -n "${vqsrinfile}" ] && [ -n "${vqsrinfilepadding}" ]; then
	interval="-L ${vqsrinfile} -ip ${vqsrinfilepadding} -isr INTERSECTION"
elif [ -n "${vqsrinfile}" ]; then
	interval="-L ${vqsrinfile} -isr INTERSECTION"
fi

for CONTIG in ${CONTIGARRAY[@]}; do
	input="${input} --variant ${PROJECT_PATH}/genotype/${CONTIG}_gen.vcf.gz"
done

scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=Recalibrator_${PROJECT}_${MODE}
# Here we need to output to scratch, as these files are going to be used by the next job - and we don't want them to be erased! # make this directory if it doesn't already exist


module purge
module load R
module load GATK4 #/4.1.8.1-GCCcore-8.3.0-Java-1.8 #/4.1.4.1-GCCcore-8.3.0-Java-1.8 # Additional VCF validation has been added as of 4.1.5. Some reference allele do not match anymore.

cmd="srun gatk --java-options -Xmx16g \
	VariantRecalibrator \
	-R ${REFA} \
	${input} \
	${interval} \
	${AS} \
	${maxgaus} \
	${resources} \
	${annotations} \
	-mode ${MODE} \
	${tranches} \
	--output ${PROJECT_PATH}/recalibrate/${MODE}output.recal.vcf.gz \
	--tranches-file ${PROJECT_PATH}/recalibrate/${MODE}output.tranches \
	--rscript-file ${PROJECT_PATH}/recalibrate/${MODE}output.plots.R"
echo $cmd
mkdir -p ${PROJECT_PATH}/recalibrate
eval $cmd || exit 1$?
mkdir -p ${PROJECT_PATH}/done/recalibrate
touch ${PROJECT_PATH}/done/recalibrate/${MODE}output.recal.done || exit 1

exit 0
