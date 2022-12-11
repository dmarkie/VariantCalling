#!/bin/bash
#applyrecal.sl

#SBATCH --job-name	ApplyRecal
#SBATCH --time		12:00:00
#SBATCH --mem		24G
#SBATCH --cpus-per-task	2
#SBATCH --error		slurm/applyrecal/applyrecal-%A_%a.out
#SBATCH --output	slurm/applyrecal/applyrecal-%A_%a.out

echo "$(date) on $(hostname)"

source ${PROJECT_PATH}/parameters.sh

if [ $allelespecific == "yes" ]; then AS="-AS"; fi

if [ -n "${vqsrinfile}" ] && [ -n "${vqsrinfilepadding}" ]; then
	interval="-L ${vqsrinfile} -ip ${vqsrinfilepadding}"
elif [ -n "${vqsrinfile}" ]; then
	interval="-L ${vqsrinfile}"
fi

CONTIG=${CONTIGARRAY[$(( ${SLURM_ARRAY_TASK_ID} - 1 ))]}

if [ "${CONTIG}" == "" ]; then
	echo "FAIL: Invalid contig defined at $SLURM_ARRAY_TASK_ID"
	exit 1
fi

module purge
module load GATK4

if [ -f ${PROJECT_PATH}/done/applyrecal/${CONTIG}_SNPrecal.vcf.gz.done ]; then
	echo "INFO: SNP recalibration for ${CONTIG} already complete."
else
# update the job name so you can see the progress in squeue
	scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=ApplySNPrecal_${PROJECT}_${CONTIG}

	cmd="srun gatk --java-options -Xmx12g \
		ApplyVQSR \
		-R $REFA \
		-V ${PROJECT_PATH}/genotype/${CONTIG}_gen.vcf.gz \
		${interval} \
		${AS} \
		--tranches-file ${PROJECT_PATH}/recalibrate/SNPoutput.tranches \
		--recal-file ${PROJECT_PATH}/recalibrate/SNPoutput.recal.vcf.gz \
		-O ${PROJECT_PATH}/applyrecal/${CONTIG}_SNPrecal.vcf.gz \
		-ts-filter-level 99.5 \
		-jdk-deflater \
		-jdk-inflater \
		--mode SNP"
	mkdir -p ${PROJECT_PATH}/applyrecal
	echo $cmd
	eval $cmd || exit 1$?
	mkdir -p ${PROJECT_PATH}/done/applyrecal
	touch ${PROJECT_PATH}/done/applyrecal/${CONTIG}_SNPrecal.vcf.gz.done
fi

if [ -f ${PROJECT_PATH}/done/applyrecal/${CONTIG}_recal.vcf.gz.done ]; then
	echo "INFO: INDEL recalibration for ${CONTIG} already complete."
else
	scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=ApplyINDELrecal_${PROJECT}_${CONTIG}

	cmd="srun gatk --java-options -Xmx12g \
		ApplyVQSR \
		-R $REFA \
		-V ${PROJECT_PATH}/applyrecal/${CONTIG}_SNPrecal.vcf.gz \
		${interval} \
		${AS} \
		--tranches-file ${PROJECT_PATH}/recalibrate/INDELoutput.tranches \
		--recal-file ${PROJECT_PATH}/recalibrate/INDELoutput.recal.vcf.gz \
		-O ${PROJECT_PATH}/applyrecal/${CONTIG}_recal.vcf.gz \
		-ts-filter-level 99.0 \
		-jdk-deflater \
		-jdk-inflater \
		--mode INDEL"

	echo $cmd
	eval $cmd || exit 1$?
	touch ${PROJECT_PATH}/done/applyrecal/${CONTIG}_recal.vcf.gz.done
	if [ -f ${PROJECT_PATH}/genotype/${CONTIG}_gen.vcf.gz ]; then
		rm ${PROJECT_PATH}/genotype/${CONTIG}_gen.vcf.gz
	fi
fi

exit 0


