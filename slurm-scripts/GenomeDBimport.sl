#!/bin/bash
#GenomeDBimport.sl - for joint genotyping gvcf files for contigs

#SBATCH --job-name	GenomeDB
#SBATCH --time		10-00:00:00
#SBATCH --cpus-per-task	2
#SBATCH --mem		16G
#SBATCH --error		slurm/GenomeDB/import-%A_%a.out
#SBATCH --output	slurm/GenomeDB/import-%A_%a.out

#MPORTANT: The -Xmx value the tool is run with should be less than the total amount of physical memory available by at least a few GB,
# as the native TileDB library requires additional memory on top of the Java memory. Failure to leave enough memory for the native code
# can result in confusing error messages!

echo "$(date) on $(hostname)"

source ${PROJECT_PATH}/parameters.sh

CONTIG=${CONTIGARRAY[$(( ${SLURM_ARRAY_TASK_ID} - 1 ))]}

if [ "${CONTIG}" == "" ]; then
	echo "FAIL: Invalid contig defined at ${SLURM_ARRAY_TASK_ID}"
	exit 1
fi

module purge
module load GATK4

if [ -f ${PROJECT_PATH}/done/GenomeDB/GenomicsDBImport_${CONTIG}.done ]; then
	echo "INFO: GenomicsDBimport for ${CONTIG} already complete."
else
	scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=GenomeDBimport_${CONTIG}
	mkdir -p ${PROJECT_PATH}/GenomeDB
	if [ -d ${PROJECT_PATH}/GenomeDB/GenomeDB_${CONTIG} ]; then
		rm -r ${PROJECT_PATH}/GenomeDB/GenomeDB_${CONTIG}
	fi
	cmd="srun -J GenomeDBimport_${CONTIG} \
gatk --java-options \"-Xmx8g -Xms8g\" \
GenomicsDBImport \
-R ${REFA}
--genomicsdb-workspace-path ${PROJECT_PATH}/GenomeDB/GenomeDB_${CONTIG} \
--batch-size 50 \
-L ${CONTIG} \
--sample-name-map ${PROJECT_PATH}/samplemap.txt \
--tmp-dir ${TMPDIR} \
--reader-threads $SLURM_CPUS_PER_TASK"
	echo ${cmd}
	eval ${cmd} || exit 1$?
	mkdir -p ${PROJECT_PATH}/done/GenomeDB
	touch ${PROJECT_PATH}/done/GenomeDB/GenomicsDBImport_${CONTIG}.done
fi

exit 0
