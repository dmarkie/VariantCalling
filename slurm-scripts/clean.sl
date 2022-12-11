#!/bin/bash
# clean.sl
#SBATCH --job-name	Clean
#SBATCH --time		1:00:00
#SBATCH --mem		1G
#SBATCH --cpus-per-task	1
#SBATCH --error		VariantCallCleanup-%j.out
#SBATCH --output	VariantCallCleanup-%j.out

source ${PROJECT_PATH}/parameters.sh
echo "$(date) on $(hostname)"
if [ ! -f ${PROJECT_PATH}/done/move/${PROJECT}_MendelianViolationMetrics.txt.move.done ]; then
	cmd="mv ${PROJECT_PATH}/${PROJECT}_MendelianViolationMetrics.txt ${outputdir}"
	echo ${cmd}
	eval ${cmd} || exit 1
	touch ${PROJECT_PATH}/done/move/${PROJECT}_MendelianViolationMetrics.txt.move.done
else
	echo "INFO: Output from move for ${PROJECT}_MendelianViolations.txt already available"
fi
if [ -d ${PROJECT_PATH}/merge ]; then
	cmd="srun rm -r ${PROJECT_PATH}/merge"
	echo $cmd
	eval $cmd || exit 1
fi
if [ -d ${PROJECT_PATH} ]; then
	COUNT=0
	cmd="srun tar --exclude-vcs -zcf ${outputdir}/${PROJECT}.tar.gz ${PROJECT_PATH}"
	echo ${cmd}
	until [ $COUNT -gt 10 ] || eval ${cmd}
	do
		((COUNT++))
		sleep 20s
		(echo "--FAILURE--      Sending compressed archive of ${PROJECT_PATH} to ${outputdir} failed. Retrying..." 1>&2)
	done
	if [ $COUNT -le 10 ]
	then
		cmd="srun rm -r ${PROJECT_PATH}"
		echo $cmd
		eval $cmd || exit 1
	else
		(echo "--FAILURE--      Unable to send compressed archive of ${PROJECT_PATH} to ${outputdir}" 1>&2)
		exit 1
	fi
fi
echo -e "It looks like you have successfully completed your Variant Call which should now be located in the directory ${outputdir}.\nYou can now delete this file."
exit 0
