#!/bin/bash
#Copy.sl - for joint genotyping gvcf files for contigs

#SBATCH --job-name	GenomeDB
#SBATCH --time		10-00:00:00
#SBATCH --cpus-per-task	2
#SBATCH --mem		2G
#SBATCH --error		slurm/GenomeDB/import-%A_%a.out
#SBATCH --output	slurm/GenomeDB/import-%A_%a.out

echo "$(date) on $(hostname)"

source ${PROJECT_PATH}/parameters.sh

CONTIG=${CONTIGARRAY[$(( ${SLURM_ARRAY_TASK_ID} - 1 ))]}

if [ "${CONTIG}" == "" ]; then
	echo "FAIL: Invalid contig defined at ${SLURM_ARRAY_TASK_ID}"
	exit 1
fi
if [ -f ${PROJECT_PATH}/done/GenomeDB/GenomicsDBImport_${CONTIG}.done ]; then
	echo "INFO: GenomicsDBimport for ${CONTIG} already complete."
else
	scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=Copy_${CONTIG}_${BATCH}
	mkdir -p ${PROJECT_PATH}/GenomeDB
	COUNT=0
	CMD="srun rsync -avP ${genomicsDB_workpath}/GenomeDB_${CONTIG} ${PROJECT_PATH}/GenomeDB"
	until [ $COUNT -gt 10 ] || eval ${CMD}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Syncing ${genomicsDB_workpath}/GenomeDB_${CONTIG} to ${PROJECT_PATH} failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		mkdir -p ${PROJECT_PATH}/done/GenomeDB
		touch ${PROJECT_PATH}/done/GenomeDB/GenomicsDBImport_${CONTIG}.done
	else
		(echo "--FAILURE--      Unable to move ${genomicsDB_workpath}/GenomeDB_${CONTIG} to ${PROJECT_PATH}/GenomeDB" 1>&2)
		exit 1
	fi
fi
