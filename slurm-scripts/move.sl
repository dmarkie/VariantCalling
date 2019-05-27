#!/bin/bash
# move.sl 
# this script is intended to take a collection of non-overlapping contig vcf.gz files, all with the same individuals in them, and stitch them together into one vcf.gz
#SBATCH --job-name	Move
#SBATCH --time		1:00:00
#SBATCH --mem		1G
#SBATCH --cpus-per-task	1
#SBATCH --mail-type FAIL,END
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
	cmd="mv ${PROJECT_PATH}/${PROJECT}_GenderReport.txt ${outputdir}"
	mkdir -p ${PROJECT_PATH}/done/move
	echo ${cmd}
	eval ${cmd} || exit 1
	touch ${PROJECT_PATH}/done/move/${PROJECT}_GenderReport.txt.move.done
else
	echo "INFO: Output from move for ${PROJECT}_GenderReport.txt already available"
fi
if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}_MendelianViolationMetrics.txt.move.done ]; then
	cmd="mv ${PROJECT_PATH}/${PROJECT}_MendelianViolationMetrics.txt ${outputdir}"
	echo ${cmd}
	eval ${cmd} || exit 1
	touch ${PROJECT_PATH}/done/move/${PROJECT}_MendelianViolationMetrics.txt.move.done
else
	echo "INFO: Output from move for ${PROJECT}_MendelianViolations.txt already available"
fi
if [ ! -f ${PROJECT_PATH}/done/move/SNPoutput.tranches.pdf.move.done ]; then
	cmd="mv ${PROJECT_PATH}/recalibrate/SNPoutput.tranches.pdf ${outputdir}"
	echo ${cmd}
	eval ${cmd} || exit 1
	touch ${PROJECT_PATH}/done/move/SNPoutput.tranches.pdf.move.done
else
	echo "INFO: Output from move for SNPoutput.tranches.pdf already available"
fi
if [ ! -f ${PROJECT_PATH}/done/move/SNPoutput.plots.R.pdf.move.done ]; then
	cmd="mv ${PROJECT_PATH}/recalibrate/SNPoutput.plots.R.pdf ${outputdir}"
	echo ${cmd}
	eval ${cmd} || exit 1
	touch ${PROJECT_PATH}/done/move/SNPoutput.plots.R.pdf.move.done
else
	echo "INFO: Output from move for SNPoutput.plots.R.pdf already available"
fi
if [ ! -f ${PROJECT_PATH}/done/move/INDELoutput.plots.R.pdf.move.done ]; then
	cmd="mv ${PROJECT_PATH}/recalibrate/INDELoutput.plots.R.pdf ${outputdir}"
	echo ${cmd}
	eval ${cmd} || exit 1
	touch ${PROJECT_PATH}/done/move/INDELoutput.plots.R.pdf.move.done
else
	echo "INFO: Output from move for INDELoutput.plots.R.pdf already available"
fi
if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}.vcf.gz.move.done ]; then
	cmd="mv ${PROJECT_PATH}/merge/${PROJECT}.vcf.gz ${outputdir}/PrimaryCall"
	echo ${cmd}
	eval ${cmd} || exit 1
	touch ${PROJECT_PATH}/done/move/${PROJECT}.vcf.gz.move.done
else
	echo "INFO: Output from move for ${PROJECT}.vcf.gz already available"
fi
if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}.vcf.gz.tbi.move.done ]; then
	cmd="mv ${PROJECT_PATH}/merge/${PROJECT}.vcf.gz.tbi ${outputdir}/PrimaryCall"
	echo ${cmd}
	eval ${cmd} || exit 1
	touch ${PROJECT_PATH}/done/move/${PROJECT}.vcf.gz.tbi.move.done
else
	echo "INFO: Output from move for ${PROJECT}.vcf.gz.tbi already available"
fi
if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}_ID.list.move.done ]; then
	cmd="mv ${PROJECT_PATH}/merge/${PROJECT}_ID.list ${outputdir}/PrimaryCall"
	echo ${cmd}
	eval ${cmd} || exit 1
	touch ${PROJECT_PATH}/done/move/${PROJECT}_ID.list.move.done
else
	echo "INFO: Output from move for ${PROJECT}_ID.list already available"
fi
if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}_Split.vcf.gz.move.done ]; then
	cmd="mv ${PROJECT_PATH}/mergesplit/${PROJECT}_Split.vcf.gz ${outputdir}/SplitMultiallelics"
	echo ${cmd}
	eval ${cmd} || exit 1
	touch ${PROJECT_PATH}/done/move/${PROJECT}_Split.vcf.gz.move.done
else
	echo "INFO: Output from move for ${PROJECT}_Split.vcf.gz already available"
fi
if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}_Split.vcf.gz.tbi.move.done ]; then
	cmd="mv ${PROJECT_PATH}/mergesplit/${PROJECT}_Split.vcf.gz.tbi ${outputdir}/SplitMultiallelics"
	echo ${cmd}
	eval ${cmd} || exit 1
	touch ${PROJECT_PATH}/done/move/${PROJECT}_Split.vcf.gz.tbi.move.done
else
	echo "INFO: Output from move for ${PROJECT}_Split.vcf.gz.tbi already available"
fi
if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}_Split_ID.list.move.done ]; then
	cmd="mv ${PROJECT_PATH}/mergesplit/${PROJECT}_Split_ID.list ${outputdir}/SplitMultiallelics"
	echo ${cmd}
	eval ${cmd} || exit 1
	touch ${PROJECT_PATH}/done/move/${PROJECT}_Split_ID.list.move.done
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
if [ -d ${PROJECT_PATH}/merge ]; then
	cmd="srun rm -r ${PROJECT_PATH}/merge"
	echo $cmd
	eval $cmd || exit 1
fi
if [ -d ${PROJECT_PATH}/mergesplit ]; then
	cmd="srun rm -r ${PROJECT_PATH}/mergesplit"
	echo $cmd
	eval $cmd || exit 1
fi
if [ ! -f ${PROJECT_PATH}/done/move/ped.txt.move.done ]; then
	cmd="cp ${PROJECT_PATH}/ped.txt ${outputdir}"
	echo ${cmd}
	eval ${cmd} || exit 1
	mkdir -p ${PROJECT_PATH}/done/move
	touch ${PROJECT_PATH}/done/move/ped.txt.move.done
else
	echo "INFO: Output from copy for ped.txt already available"
fi
if [ ! -f ${PROJECT_PATH}/done/move/samplemap.txt.move.done ]; then
	cmd="cp ${PROJECT_PATH}/samplemap.txt ${outputdir}"
	echo ${cmd}
	eval ${cmd} || exit 1
	mkdir -p ${PROJECT_PATH}/done/move
	touch ${PROJECT_PATH}/done/move/samplemap.txt.move.done
else
	echo "INFO: Output from copy for samplemap.txt already available"
fi
if [ ! -f ${PROJECT_PATH}/done/move/parameterfile.move.done ]; then
	cmd="cp ${parameterfile} ${outputdir}"
	echo ${cmd}
	eval ${cmd} || exit 1
	touch ${PROJECT_PATH}/done/move/parameterfile.move.done
else
	echo "INFO: Output from copy for parameterfile already available"
fi
touch ${PROJECT_PATH}/done/move/directoriesremoved.done
exit 0
