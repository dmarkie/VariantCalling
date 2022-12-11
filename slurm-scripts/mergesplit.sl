#!/bin/bash
# mergesplit.sl
# this script is intended to take a collection of non-overlapping contig vcf.gz files, all with the same individuals in them, and stitch them together into one vcf.gz
#SBATCH --job-name	Merge
#SBATCH --time		12:00:00
#SBATCH --mem		12G
#SBATCH --cpus-per-task	2
#SBATCH --error		slurm/mergesplit/mergesplit-%j.out
#SBATCH --output	slurm/mergesplit/mergesplit-%j.out

echo "$(date) on $(hostname)"
source ${PROJECT_PATH}/parameters.sh

#####Now do the merge for all the SplitMulti files
scontrol update jobid=${SLURM_JOB_ID} jobname=Merge_${PROJECT}_Split

for CONTIG in ${CONTIGARRAY[@]}; do
	variant="${variant} -I ${PROJECT_PATH}/split/${CONTIG}_Split.vcf.gz"
done

splitmergeout="${PROJECT_PATH}/mergesplit/${PROJECT}_Split.vcf.gz"
mkdir -p ${PROJECT_PATH}/mergesplit
if [  ! -f ${PROJECT_PATH}/done/mergesplit/$(basename ${splitmergeout}).done ]; then
	module purge
	module load GATK4
	cmd="srun gatk --java-options -Xmx8g MergeVcfs \
		${variant} \
		-D ${REFD} \
		-O ${splitmergeout}"
	echo $cmd
	eval $cmd || exit 1$?
	mkdir -p ${PROJECT_PATH}/done/mergesplit
	touch ${PROJECT_PATH}/done/mergesplit/$(basename ${splitmergeout}).done
else
	echo "INFO: Output from Merge for ${splitmergeout} already available"
fi
module purge
module load BCFtools
# generate the list of IDs
if [ -f ${PROJECT_PATH}/done/mergesplit/${PROJECT}_Split_ID.list.done ]; then
	echo "INFO: Output from Merge for ${PROJECT}_Split_ID.list already available"
else
	cmd="$(which bcftools) query -l ${splitmergeout} > ${PROJECT_PATH}/mergesplit/${PROJECT}_Split_ID.list"
	echo $cmd
	eval $cmd || exit 1$?
	touch ${PROJECT_PATH}/done/mergesplit/${PROJECT}_Split_ID.list.done
fi
if [ -d ${PROJECT_PATH}/split ]; then
	rm -r ${PROJECT_PATH}/split
fi

exit 0
