#!/bin/bash
# move.sl
# this script is intended to take a collection of non-overlapping contig vcf.gz files, all with the same individuals in them, and stitch them together into one vcf.gz
#SBATCH --job-name	Move
#SBATCH --time		10:00:00
#SBATCH --mem		1G
#SBATCH --cpus-per-task	1
#SBATCH --error		slurm/move/move-%j.out
#SBATCH --output	slurm/move/move-%j.out

echo "$(date) on $(hostname)"
source ${PROJECT_PATH}/parameters.sh

if ! mkdir -p ${outputdir}; then
	echo "Error creating destination folder!"
	exit 1
fi
mkdir -p ${outputdir}/PrimaryCall
mkdir -p ${outputdir}/SplitMultiallelics
scontrol update jobid=${SLURM_JOB_ID} jobname=Movingstuff_${PROJECT}
if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}_GenderReport.txt.move.done ]; then
	COUNT=0
	cmd="srun rsync -avP ${PROJECT_PATH}/${PROJECT}_GenderReport.txt ${outputdir}"
	echo ${cmd}
	until [ $COUNT -gt 10 ] || eval ${cmd}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Syncing ${PROJECT_PATH}/${PROJECT}_GenderReport.txt to ${outputdir} failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		mkdir -p ${PROJECT_PATH}/done/move
		touch ${PROJECT_PATH}/done/move/${PROJECT}_GenderReport.txt.move.done
	else
		(echo "--FAILURE--      Unable to move ${PROJECT_PATH}/${PROJECT}_GenderReport.txt to ${outputdir}" 1>&2)
		exit 1
	fi
else
	echo "INFO: Output from move for ${PROJECT}_GenderReport.txt already available"
fi

if [ ! -f ${PROJECT_PATH}/done/move/SNPoutput.tranches.pdf.move.done ]; then
	COUNT=0
	cmd="srun rsync -avP ${PROJECT_PATH}/recalibrate/SNPoutput.tranches.pdf ${outputdir}"
	echo ${cmd}
	until [ $COUNT -gt 10 ] || eval ${cmd}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Syncing ${PROJECT_PATH}/recalibrate/SNPoutput.tranches.pdf to ${outputdir} failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		touch ${PROJECT_PATH}/done/move/SNPoutput.tranches.pdf.move.done
	else
		(echo "--FAILURE--      Unable to move ${PROJECT_PATH}/recalibrate/SNPoutput.tranches.pdf to ${outputdir}" 1>&2)
		exit 1
	fi
else
	echo "INFO: Output from move for SNPoutput.tranches.pdf already available"
fi

if [ ! -f ${PROJECT_PATH}/done/move/SNPoutput.plots.R.pdf.move.done ]; then
	COUNT=0
	cmd="srun rsync -avP ${PROJECT_PATH}/recalibrate/SNPoutput.plots.R.pdf ${outputdir}"
	echo ${cmd}
	until [ $COUNT -gt 10 ] || eval ${cmd}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Syncing ${PROJECT_PATH}/recalibrate/SNPoutput.plots.R.pdf to ${outputdir} failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		touch ${PROJECT_PATH}/done/move/SNPoutput.plots.R.pdf.move.done
	else
		(echo "--FAILURE--      Unable to move ${PROJECT_PATH}/recalibrate/SNPoutput.plots.R.pdf to ${outputdir}" 1>&2)
		exit 1
	fi
else
	echo "INFO: Output from move for SNPoutput.plots.R.pdf already available"
fi

if [ ! -f ${PROJECT_PATH}/done/move/INDELoutput.plots.R.pdf.move.done ]; then
	COUNT=0
	cmd="srun rsync -avP ${PROJECT_PATH}/recalibrate/INDELoutput.plots.R.pdf ${outputdir}"
	echo ${cmd}
	until [ $COUNT -gt 10 ] || eval ${cmd}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Syncing ${PROJECT_PATH}/recalibrate/INDELoutput.plots.R.pdf to ${outputdir} failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		touch ${PROJECT_PATH}/done/move/INDELoutput.plots.R.pdf.move.done
	else
		(echo "--FAILURE--      Unable to move ${PROJECT_PATH}/recalibrate/INDELoutput.plots.R.pdf to ${outputdir}" 1>&2)
		exit 1
	fi
else
	echo "INFO: Output from move for INDELoutput.plots.R.pdf already available"
fi

if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}.vcf.gz.move.done ]; then
	COUNT=0
	cmd="srun rsync -avP ${PROJECT_PATH}/merge/${PROJECT}.vcf.gz ${outputdir}/PrimaryCall"
	echo ${cmd}
	until [ $COUNT -gt 10 ] || eval ${cmd}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Syncing ${PROJECT_PATH}/merge/${PROJECT}.vcf.gz to ${outputdir}/PrimaryCall failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		touch ${PROJECT_PATH}/done/move/${PROJECT}.vcf.gz.move.done
	else
		(echo "--FAILURE--      Unable to move ${PROJECT_PATH}/merge/${PROJECT}.vcf.gz to ${outputdir}/PrimaryCall" 1>&2)
		exit 1
	fi
else
	echo "INFO: Output from move for ${PROJECT}.vcf.gz already available"
fi
if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}.vcf.gz.tbi.move.done ]; then
	COUNT=0
	cmd="srun rsync -avP ${PROJECT_PATH}/merge/${PROJECT}.vcf.gz.tbi ${outputdir}/PrimaryCall"
	echo ${cmd}
	until [ $COUNT -gt 10 ] || eval ${cmd}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Syncing ${PROJECT_PATH}/merge/${PROJECT}.vcf.gz.tbi to ${outputdir}/PrimaryCall failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		touch ${PROJECT_PATH}/done/move/${PROJECT}.vcf.gz.tbi.move.done
	else
		(echo "--FAILURE--      Unable to move ${PROJECT_PATH}/merge/${PROJECT}.vcf.gz.tbi to ${outputdir}/PrimaryCall" 1>&2)
		exit 1
	fi
else
	echo "INFO: Output from move for ${PROJECT}.vcf.gz.tbi already available"
fi

if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}_ID.list.move.done ]; then
	COUNT=0
	cmd="srun rsync -avP ${PROJECT_PATH}/merge/${PROJECT}_ID.list ${outputdir}/PrimaryCall"
	echo ${cmd}
	until [ $COUNT -gt 10 ] || eval ${cmd}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Syncing ${PROJECT_PATH}/merge/${PROJECT}_ID.list to ${outputdir}/PrimaryCall failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		touch ${PROJECT_PATH}/done/move/${PROJECT}_ID.list.move.done
	else
		(echo "--FAILURE--      Unable to move ${PROJECT_PATH}/merge/${PROJECT}_ID.list to ${outputdir}/PrimaryCall" 1>&2)
		exit 1
	fi
else
	echo "INFO: Output from move for ${PROJECT}_ID.list already available"
fi

if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}_Split.vcf.gz.move.done ]; then
	COUNT=0
	cmd="srun rsync -avP ${PROJECT_PATH}/mergesplit/${PROJECT}_Split.vcf.gz ${outputdir}/SplitMultiallelics"
	echo ${cmd}
	until [ $COUNT -gt 10 ] || eval ${cmd}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Syncing ${PROJECT_PATH}/mergesplit/${PROJECT}_Split.vcf.gz to ${outputdir}/SplitMultiallelics failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		touch ${PROJECT_PATH}/done/move/${PROJECT}_Split.vcf.gz.move.done
	else
		(echo "--FAILURE--      Unable to move ${PROJECT_PATH}/mergesplit/${PROJECT}_Split.vcf.gz to ${outputdir}/SplitMultiallelics" 1>&2)
		exit 1
	fi
else
	echo "INFO: Output from move for ${PROJECT}_Split.vcf.gz already available"
fi

if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}_Split.vcf.gz.tbi.move.done ]; then
	COUNT=0
	cmd="srun rsync -avP ${PROJECT_PATH}/mergesplit/${PROJECT}_Split.vcf.gz.tbi ${outputdir}/SplitMultiallelics"
	echo ${cmd}
	until [ $COUNT -gt 10 ] || eval ${cmd}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Syncing ${PROJECT_PATH}/mergesplit/${PROJECT}_Split.vcf.gz.tbi to ${outputdir}/SplitMultiallelics failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		touch ${PROJECT_PATH}/done/move/${PROJECT}_Split.vcf.gz.tbi.move.done
	else
		(echo "--FAILURE--      Unable to move ${PROJECT_PATH}/mergesplit/${PROJECT}_Split.vcf.gz.tbi to ${outputdir}/SplitMultiallelics" 1>&2)
		exit 1
	fi
else
	echo "INFO: Output from move for ${PROJECT}_Split.vcf.gz.tbi already available"
fi
if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}_Split_ID.list.move.done ]; then
	COUNT=0
	cmd="srun rsync -avP ${PROJECT_PATH}/mergesplit/${PROJECT}_Split_ID.list ${outputdir}/SplitMultiallelics"
	echo ${cmd}
	until [ $COUNT -gt 10 ] || eval ${cmd}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Syncing ${PROJECT_PATH}/mergesplit/${PROJECT}_Split_ID.list to ${outputdir}/SplitMultiallelics failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		touch ${PROJECT_PATH}/done/move/${PROJECT}_Split_ID.list.move.done
	else
		(echo "--FAILURE--      Unable to move ${PROJECT_PATH}/mergesplit/${PROJECT}_Split_ID.list to ${outputdir}/SplitMultiallelics" 1>&2)
		exit 1
	fi
else
	echo "INFO: Output from move for ${PROJECT}_Split_ID.list already available"
fi

# pack up the pipeline scripts and timeastamp, write to destination
if [ ! -f ${PROJECT_PATH}/done/move/$(basename ${PBIN})_$(date +%F_%H-%M-%S_%Z).tar.done ]; then
	cmd="srun tar --exclude-vcs -cf ${PROJECT_PATH}/$(basename ${PBIN})_$(date +%F_%H-%M-%S_%Z).tar ${PBIN}"
	echo ${cmd}
	eval ${cmd} || exit 1
	touch ${PROJECT_PATH}/done/move/$(basename ${PBIN})_$(date +%F_%H-%M-%S_%Z).tar.done
else
	echo "INFO: Output for $(basename ${PBIN})_$(date +%F_%H-%M-%S_%Z).tar already available"
fi
#delete stuff
if [ -d ${PROJECT_PATH}/GenomeDB ]; then
	cmd="srun rm -r ${PROJECT_PATH}/GenomeDB"
	echo $cmd
	eval $cmd || exit 1
fi
if [ -d ${PROJECT_PATH}/genotype ]; then
	cmd="srun rm -r ${PROJECT_PATH}/genotype"
	echo $cmd
	eval $cmd || exit 1
fi
if [ -d ${PROJECT_PATH}/recalibrate ]; then
	cmd="srun rm -r ${PROJECT_PATH}/recalibrate"
	echo $cmd
	eval $cmd || exit 1
fi
if [ -d ${PROJECT_PATH}/applyrecal ]; then
	cmd="srun rm -r ${PROJECT_PATH}/applyrecal"
	echo $cmd
	eval $cmd || exit 1
fi
if [ -d ${PROJECT_PATH}/refinement ]; then
	cmd="srun rm -r ${PROJECT_PATH}/refinement"
	echo $cmd
	eval $cmd || exit 1
fi
if [ -d ${PROJECT_PATH}/split ]; then
	cmd="srun rm -r ${PROJECT_PATH}/split"
	echo $cmd
	eval $cmd || exit 1
fi
if [ -d ${PROJECT_PATH}/mergesplit ]; then
	cmd="srun rm -r ${PROJECT_PATH}/mergesplit"
	echo $cmd
	eval $cmd || exit 1
fi

if [ ! -f ${PROJECT_PATH}/done/move/ped.txt.move.done ]; then
	COUNT=0
	cmd="srun rsync -avP ${PROJECT_PATH}/ped.txt ${outputdir}"
	echo ${cmd}
	until [ $COUNT -gt 10 ] || eval ${cmd}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Syncing ${PROJECT_PATH}/ped.txt to ${outputdir} failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		touch ${PROJECT_PATH}/done/move/ped.txt.move.done
	else
		(echo "--FAILURE--      Unable to move ${PROJECT_PATH}/ped.txt to ${outputdir}" 1>&2)
		exit 1
	fi
else
	echo "INFO: Output from move for ped.txt already available"
fi

if [ ! -f ${PROJECT_PATH}/done/move/samplemap.txt.move.done ]; then
	COUNT=0
	cmd="srun rsync -avP ${PROJECT_PATH}/samplemap.txt ${outputdir}"
	echo ${cmd}
	until [ $COUNT -gt 10 ] || eval ${cmd}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Syncing ${PROJECT_PATH}/samplemap.txt to ${outputdir} failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		touch ${PROJECT_PATH}/done/move/samplemap.txt.move.done
	else
		(echo "--FAILURE--      Unable to move ${PROJECT_PATH}/samplemap.txt to ${outputdir}" 1>&2)
		exit 1
	fi
else
	echo "INFO: Output from move for samplemap.txt already available"
fi

if [ ! -f ${PROJECT_PATH}/done/move/parameterfile.move.done ]; then
	COUNT=0
	cmd="srun rsync -avP ${parameterfile} ${outputdir}"
	echo ${cmd}
	until [ $COUNT -gt 10 ] || eval ${cmd}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Syncing ${parameterfile} to ${outputdir} failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		touch ${PROJECT_PATH}/done/move/parameterfile.move.done
	else
		(echo "--FAILURE--      Unable to move ${parameterfile} to ${outputdir}" 1>&2)
		exit 1
	fi
else
	echo "INFO: Output from move for $(basename ${parameterfile}) already available"
fi

touch ${PROJECT_PATH}/done/move/directoriesremoved.done
exit 0
