#!/bin/bash
#splitmultiallelic.sl 

#SBATCH --job-name	SplitMulti
#SBATCH --time		8:00:00
#SBATCH --mem		1G
#SBATCH --cpus-per-task	2
#SBATCH --mail-type FAIL,END
#SBATCH --error		slurm/split/split-%A_%a.out
#SBATCH --output	slurm/split/split-%A_%a.out


echo "$(date) on $(hostname)"
source ${PROJECT_PATH}/parameters.sh

CONTIG=${CONTIGARRAY[$(( ${SLURM_ARRAY_TASK_ID} - 1 ))]}

if [ "${CONTIG}" == "" ]; then
	echo "FAIL: Invalid contig defined at $SLURM_ARRAY_TASK_ID"
	exit 1
fi

variant=${PROJECT_PATH}/refinement/${CONTIG}_refine.vcf.gz
mkdir -p ${PROJECT_PATH}/split
#Although GATK4/4.0.12.0 can split multiallelics for trisomic samples eg XXX females, it messes up the output when an individual is heterozygous for two alt alleles - makes everybody into no calls. This is not fixed in GATK4.1.0.0
# Until then use bcftools norm - this however has the problem that samples with trisomic called regions eg XXX females can not be processed and need to be excluded prior to splitting.
# need to do the gender check right at the beginning and make a file with the IDs with trisomic (or more) sex chromosomes.
module purge
module load BCFtools
if [ ${sexchromosomes} == "yes" ]; then
	supernumary=$(awk '$5 ~ /^XXX|XXY|XYY|XXXX|XXXY|XYYY$/ { print $1 }' ${PROJECT_PATH}/${PROJECT}_GenderReport.txt | wc -l)
else
	supernumary=0
fi
if [ ${supernumary} -gt 0 ]; then
	superstring=$(awk '$5 ~ /^XXX|XXY|XYY|XXXX|XXXY|XYYY$/ { print $1 }' ${PROJECT_PATH}/${PROJECT}_GenderReport.txt | tr "\n" "," | sed 's/,$//')
	if [ -f ${PROJECT_PATH}/done/split/${CONTIG}_exclude.vcf.gz.done ]; then
		echo "INFO: Output excluding supernumary sex chromosome samples from contig ${CONTIG} already available"
	else
		scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=Exclude_${PROJECT}_${CONTIG}
		cmd="$(which bcftools) view -s ^${superstring} ${variant} -Oz -o ${PROJECT_PATH}/split/${CONTIG}_exclude.vcf.gz"
		echo $cmd
		mkdir -p ${PROJECT_PATH}/split
		eval $cmd || exit 1$?
		mkdir -p ${PROJECT_PATH}/done/split
		touch ${PROJECT_PATH}/done/split/${CONTIG}_exclude.vcf.gz.done
	fi
	if [ -f ${PROJECT_PATH}/done/split/${CONTIG}_exclude.vcf.gz.tbi.done ]; then
		echo "INFO: Index excluding supernumary sex chromosome samples from contig ${CONTIG} already available"
	else
		scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=IndexExclude_${PROJECT}_${CONTIG}
		cmd="$(which bcftools) index -t ${PROJECT_PATH}/split/${CONTIG}_exclude.vcf.gz"
		echo $cmd
		eval $cmd || exit 1$?
		touch ${PROJECT_PATH}/done/split/${CONTIG}_exclude.vcf.gz.tbi.done
	fi
	variant=${PROJECT_PATH}/split/${CONTIG}_exclude.vcf.gz
fi
if [ ${supernumary} -gt 0 ]; then
	variant=${PROJECT_PATH}/split/${CONTIG}_exclude.vcf.gz
fi
if [ -f ${PROJECT_PATH}/done/split/${CONTIG}_Split.vcf.gz.done ]; then
	echo "INFO: Output from splitting multiallelics for contig ${CONTIG} already available"
else
	scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=SplitMulti_${PROJECT}_${CONTIG}
	# have made this in to a two step process because it is possible that they need to be split first then left aligned and normalised 
	cmd="$(which bcftools) norm -m -any ${variant} | $(which bcftools) norm -f ${REFA} -Oz -o ${PROJECT_PATH}/split/${CONTIG}_Split.vcf.gz"
	mkdir -p ${PROJECT_PATH}/split
	set -o pipefail
	echo $cmd
	eval $cmd || exit 1$?
	mkdir -p ${PROJECT_PATH}/done/split
	touch ${PROJECT_PATH}/done/split/${CONTIG}_Split.vcf.gz.done
fi
if [ -f ${PROJECT_PATH}/split/${CONTIG}_exclude.vcf.gz ]; then
	rm ${PROJECT_PATH}/split/${CONTIG}_exclude.vcf.gz
fi
if [ -f ${PROJECT_PATH}/split/${CONTIG}_exclude.vcf.gz.tbi ]; then
	rm ${PROJECT_PATH}/split/${CONTIG}_exclude.vcf.gz.tbi
fi
if [ -f ${PROJECT_PATH}/done/split/${CONTIG}_Split.vcf.gz.tbi.done ]; then
	echo "INFO: Index from splitting multiallelics for contig ${CONTIG} already available"
else
	scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=IndexSplit_${PROJECT}_${CONTIG}
	cmd="$(which bcftools) index -t ${PROJECT_PATH}/split/${CONTIG}_Split.vcf.gz"
	echo $cmd
	eval $cmd || exit 1$?
	touch ${PROJECT_PATH}/done/split/${CONTIG}_Split.vcf.gz.tbi.done
fi


#module load GATK4
#cmd="srun gatk --java-options -Xmx4g LeftAlignAndTrimVariants -R ${REFA} --max-indel-length 400 -V ${variant} -O ${PROJECT_PATH}/${CONTIG}_Split.vcf.gz --split-multi-allelics --dont-trim-alleles --keep-original-ac"

exit 0
