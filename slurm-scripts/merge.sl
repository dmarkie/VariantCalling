#!/bin/bash
# merge.sl
# this script is intended to take a collection of non-overlapping contig vcf.gz files, all with the same individuals in them, and stitch them together into one vcf.gz
#SBATCH --job-name	Merge
#SBATCH --time		2:00:00
#SBATCH --mem		12G
#SBATCH --cpus-per-task	2
#SBATCH --error		slurm/merge/merge-%j.out
#SBATCH --output	slurm/merge/merge-%j.out

echo "$(date) on $(hostname)"
source ${PROJECT_PATH}/parameters.sh

# generate the list of inputs
for CONTIG in ${CONTIGARRAY[@]}; do
	variant="${variant} -I ${PROJECT_PATH}/refinement/${CONTIG}_refine.vcf.gz"
done

scontrol update jobid=${SLURM_JOB_ID} jobname=Merge_${PROJECT}

mergeout="${PROJECT_PATH}/merge/${PROJECT}.vcf.gz"

if [ -f ${PROJECT_PATH}/done/merge/$(basename ${mergeout}).done ]; then
	echo "INFO: Output from Merge ${mergeout} already available"
else
	module purge
	module load GATK4
	cmd="srun gatk --java-options -Xmx8g MergeVcfs \
		${variant} \
		-D ${REFD} \
		-O ${mergeout}"
	echo $cmd
	mkdir -p ${PROJECT_PATH}/merge
	eval $cmd || exit 1$?
	mkdir -p ${PROJECT_PATH}/done/merge
	touch ${PROJECT_PATH}/done/merge/$(basename ${mergeout}).done
fi
module purge
module load BCFtools
# generate the list of IDs
if [ -f ${PROJECT_PATH}/done/merge/${PROJECT}_ID.list.done ]; then
	echo "INFO: Output from Merge for ${PROJECT}_ID.list already available"
else
	cmd="$(which bcftools) query -l ${mergeout} > ${PROJECT_PATH}/merge/${PROJECT}_ID.list"
	echo $cmd
	eval $cmd || exit 1$?
	touch ${PROJECT_PATH}/done/merge/${PROJECT}_ID.list.done
fi

exit 0
