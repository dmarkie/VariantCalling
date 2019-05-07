#!/bin/bash
# mergesplit.sl 
# this script is intended to take a collection of non-overlapping contig vcf.gz files, all with the same individuals in them, and stitch them together into one vcf.gz
#SBATCH --job-name	Merge
#SBATCH --time		12:00:00
#SBATCH --mem		4G
#SBATCH --cpus-per-task	2
#SBATCH --mail-type FAIL,END
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
	cmd="srun gatk --java-options -Xmx2g MergeVcfs \
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
#if [ -f ${PROJECT_PATH}/done/mergesplit/$(basename ${splitmergeout}).tbi.done ]; then
#	echo "INFO: Output from Merge for ${splitmergeout}.tbi already available"
#else
#	scontrol update jobid=${SLURM_JOB_ID} jobname=IndexMerge_${PROJECT}_Split
#	cmd="$(which bcftools) index -t ${splitmergeout}"
#	echo $cmd
#	eval $cmd || exit 1$?
#	touch ${PROJECT_PATH}/done/mergesplit/$(basename ${splitmergeout}).tbi.done
#fi
# generate the list of IDs 
if [ -f ${PROJECT_PATH}/done/mergesplit/${PROJECT}_ID.list.done ]; then
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
