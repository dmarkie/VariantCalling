#!/bin/bash
# clean.sl 
#SBATCH --job-name	Clean
#SBATCH --time		1:00:00
#SBATCH --mem		1G
#SBATCH --cpus-per-task	1
#SBATCH --mail-type FAIL,END
#SBATCH --error		VariantCallCleanup-%j.out
#SBATCH --output	VariantCallCleanup-%j.out

source ${PROJECT_PATH}/parameters.sh
echo "$(date) on $(hostname)"
if [ -d ${PROJECT_PATH} ]; then
	cmd="srun tar --exclude-vcs -zcf ${outputdir}/${PROJECT}.tar.gz ${PROJECT_PATH}"
	echo $cmd
	eval $cmd || exit 1
fi
if [ -d ${PROJECT_PATH} ]; then
	cmd="srun rm -r ${PROJECT_PATH}"
	echo $cmd
	eval $cmd || exit 1
fi
echo -e "It looks like you have successfully completed your Variant Call which should now be located in the directory ${outputdir}.\nYou can now delete this file."
exit 0