#!/bin/bash
#refinement.sl

#SBATCH --job-name	Refine
#SBATCH --time		48:00:00
#SBATCH --mem		32G
#SBATCH --cpus-per-task	2
#SBATCH --error		slurm/refinement/refinement-%A_%a.out
#SBATCH --output	slurm/refinement/refinement-%A_%a.out

echo "$(date) on $(hostname)"

source ${PROJECT_PATH}/parameters.sh

CONTIG=${CONTIGARRAY[$(( ${SLURM_ARRAY_TASK_ID} - 1 ))]}

if [ "${CONTIG}" == "" ]; then
	echo "FAIL: Invalid contig defined at $SLURM_ARRAY_TASK_ID"
	exit 1
fi

if [ -f ${popdata} ]; then
	support="-supporting ${popdata}"
fi

# If statement sorts out if it is X, Y or autosome (need to handle differently)
module purge
module load GATK4
if [ ${sexchromosomes} == "yes" ]; then
	# this needs to include X0,XXY,XYY, as it is really about the ploidy of the pseudoautosomal regions being greater than 2
	sexaneusomies=$(awk '$5 ~ /^X0|XXY|XYY|XXX|XXXX|XXXY|XYYY$/ { print $1 }' ${PROJECT_PATH}/${PROJECT}_GenderReport.txt | wc -l)
	echo -e "There are ${sexaneusomies} samples in the cohort processed as sex chromosome aneusomies."
fi
if [[ "${CONTIG}" == +(chrX*|^X*) ]] && [ ${sexchromosomes} == "yes" ]; then
	if [ ${sexaneusomies} -gt 0 ]; then
	# this option is for treating the X chromosome as a single unit during genotype refinement even when it has been processed appropriately for males and females
# it does not do genotype posteriors or de novo calling as this only works with diploid data, but does do the genotype quality filtering
# it is only necessary to run it this way when there are sex chromosome aneusomies in your data (eg XXX, XXY or X0) - because the XPAR regions are now trisomic or disomic we can't run genotype posteriors or de novo on those
		if [ -f ${PROJECT_PATH}/done/refinement/${CONTIG}_refine.vcf.gz.done ]; then
			echo "INFO: Low GQ filter for ${CONTIG} already complete."
		else
			scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=LowQual_${PROJECT}_${CONTIG}
			cmd="srun gatk --java-options -Xmx12g \
				VariantFiltration \
				-R ${REFA} \
				-O ${PROJECT_PATH}/refinement/${CONTIG}_refine.vcf.gz \
				-V ${PROJECT_PATH}/applyrecal/${CONTIG}_recal.vcf.gz \
				-L ${CONTIG} \
				-G-filter \"GQ < 20.0\" \
				-G-filter-name lowGQ"
			mkdir -p ${PROJECT_PATH}/refinement/
			echo $cmd
			eval $cmd || exit 1$?
			mkdir -p ${PROJECT_PATH}/done/refinement
			touch ${PROJECT_PATH}/done/refinement/${CONTIG}_refine.vcf.gz.done
		fi
	else
	# this option runs any XPAR regions as standard diploid (genotype posteriors, de novos and GQ filter included) but only runs GQ filter on the true X (as it will be disomic in females but monosomic in males)
	#extract the PARX regions from the recal vcf and calculate posteriors
		if [ -f ${PROJECT_PATH}/done/refinement/${CONTIG}_XPAR.vcf.gz.done ]; then
			echo "INFO: XPAR selection for ${CONTIG} already complete."
		else
			scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=Select_${PROJECT}_${CONTIG}
			cmd="srun gatk --java-options -Xmx12g \
				SelectVariants \
				-R ${REFA} \
				-V ${PROJECT_PATH}/applyrecal/${CONTIG}_recal.vcf.gz \
				-XL ${TRUEX} \
				-O ${PROJECT_PATH}/refinement/${CONTIG}_XPAR.vcf.gz"

			mkdir -p ${PROJECT_PATH}/refinement/
			echo $cmd
			eval $cmd || exit 1$?
			mkdir -p ${PROJECT_PATH}/done/refinement
			touch ${PROJECT_PATH}/done/refinement/${CONTIG}_XPAR.vcf.gz.done
		fi
		if [ -f ${PROJECT_PATH}/done/refinement/${CONTIG}_XPAR_post.vcf.gz.done ]; then
			echo "INFO: Posteriors for XPAR ${CONTIG} already complete."
		else
			scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=Posteriors_${PROJECT}_${CONTIG}
			cmd="srun gatk --java-options -Xmx68g \
				CalculateGenotypePosteriors \
				-R ${REFA} \
				-V ${PROJECT_PATH}/refinement/${CONTIG}_XPAR.vcf.gz \
				-L ${CONTIG} \
				${support} \
				-ped ${PROJECT_PATH}/ped.txt \
				--tmp-dir $TMPDIR \
				-O ${PROJECT_PATH}/refinement/${CONTIG}_XPAR_post.vcf.gz"
			echo $cmd
			eval $cmd || exit 1$?
			touch ${PROJECT_PATH}/done/refinement/${CONTIG}_XPAR_post.vcf.gz.done
			if [ -f ${PROJECT_PATH}/refinement/${CONTIG}_XPAR.vcf.gz ]; then
				rm ${PROJECT_PATH}/refinement/${CONTIG}_XPAR.vcf.gz
			fi
		fi
	#extract the truex region from the recal vcf, ready for inserting back
		if [ -f ${PROJECT_PATH}/done/refinement/${CONTIG}_TRUEX.vcf.gz.done ]; then
			echo "INFO: TRUEX selection for ${CONTIG} already complete."
		else
			scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=ExtractTrueX_${PROJECT}_${CONTIG}
			cmd="srun gatk --java-options -Xmx12g \
				SelectVariants \
				-R ${REFA} \
				-V ${PROJECT_PATH}/applyrecal/${CONTIG}_recal.vcf.gz \
				-L ${TRUEX} \
				-O ${PROJECT_PATH}/refinement/${CONTIG}_TRUEX.vcf.gz"

			echo $cmd
			eval $cmd || exit 1$?
			touch ${PROJECT_PATH}/done/refinement/${CONTIG}_TRUEX.vcf.gz.done
		fi
# GATK4 VariantAnnotator in beta and the PossibleDenovoAnnotation does not seem to be recognised
#		if [ -f ${PROJECT_PATH}/done/refinement/${CONTIG}_XPAR_denovo.vcf.gz.done ]; then
#			echo "INFO: De novo for ${CONTIG}_XPAR already complete."
#		else
#			scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=DeNovo_${PROJECT}_${CONTIG}
#			cmd="srun gatk --java-options -Xmx12g \
#				VariantAnnotator \
#				-R ${REFA} \
#				-A PossibleDeNovo \
#				-V ${PROJECT_PATH}/refinement/${CONTIG}_XPAR_post.vcf.gz \
#				-L ${CONTIG} \
#				-XL ${TRUEX} \
#				-ped ${PROJECT_PATH}/ped.txt \
#				-O ${PROJECT_PATH}/refinement/${CONTIG}_XPAR_denovo.vcf.gz"
#				# -pedValidationType SILENT \

#			echo $cmd
#			eval $cmd || exit 1$?
#			touch ${PROJECT_PATH}/done/refinement/${CONTIG}_XPAR_denovo.vcf.gz.done
#			if [ -f ${PROJECT_PATH}/refinement/${CONTIG}_XPAR_post.vcf.gz ]; then
#				rm ${PROJECT_PATH}/refinement/${CONTIG}_XPAR_post.vcf.gz
#			fi
#		fi
		if [ -f ${PROJECT_PATH}/done/refinement/${CONTIG}_remerge.vcf.gz.done ]; then
			echo "INFO: Merge for ${CONTIG} already complete."
		else
			scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=MergeX_${PROJECT}_${CONTIG}
			cmd="srun gatk --java-options -Xmx2g MergeVcfs \
				-I ${PROJECT_PATH}/refinement/${CONTIG}_XPAR_post.vcf.gz \
				-I ${PROJECT_PATH}/refinement/${CONTIG}_TRUEX.vcf.gz \
				-O ${PROJECT_PATH}/refinement/${CONTIG}_remerge.vcf.gz"
			echo $cmd
			eval $cmd || exit 1$?
			touch ${PROJECT_PATH}/done/refinement/${CONTIG}_remerge.vcf.gz.done
			if [ -f ${PROJECT_PATH}/refinement/${CONTIG}_XPAR_denovo.vcf.gz ]; then
				rm ${PROJECT_PATH}/refinement/${CONTIG}_XPAR_denovo.vcf.gz
			fi
			if [ -f ${PROJECT_PATH}/refinement/${CONTIG}_TRUEX.vcf.gz ]; then
				rm ${PROJECT_PATH}/refinement/${CONTIG}_TRUEX.vcf.gz
			fi
		fi
#		if [ -f ${PROJECT_PATH}/done/refinement/${CONTIG}_remerge.vcf.gz.tbi.done ]; then
#			echo "INFO: Index for Merge for ${CONTIG} already complete."
#		else
#			scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=IndexMergeX_${PROJECT}_${CONTIG}
#			module purge
#			module load BCFtools
#			cmd="$(which bcftools) index -t ${PROJECT_PATH}/refinement/${CONTIG}_remerge.vcf.gz"
#			echo $cmd
#			eval $cmd || exit 1$?
#			touch ${PROJECT_PATH}/done/refinement/${CONTIG}_remerge.vcf.gz.tbi.done
#		fi
		if [ -f ${PROJECT_PATH}/done/refinement/${CONTIG}_refine.vcf.gz.done ]; then
			echo "INFO: Merge for ${CONTIG} already complete."
		else
			scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=LowQual_${PROJECT}_${CONTIG}
#			module purge
#			module load GATK4
			cmd="srun gatk --java-options -Xmx12g \
				VariantFiltration \
				-R ${REFA} \
				-O ${PROJECT_PATH}/refinement/${CONTIG}_refine.vcf.gz \
				-V ${PROJECT_PATH}/refinement/${CONTIG}_remerge.vcf.gz \
				-L ${CONTIG} \
				-G-filter \"GQ < 20.0\" \
				-G-filter-name lowGQ"
			echo $cmd
			eval $cmd || exit 1$?
			touch ${PROJECT_PATH}/done/refinement/${CONTIG}_refine.vcf.gz.done
		fi
	fi
elif [[ "${CONTIG}" == +(chrY.*|Y*) ]] && [ ${sexchromosomes} == "yes" ]; then
#	module purge
#	module load GATK4
	if [ -f ${PROJECT_PATH}/done/refinement/${CONTIG}_refine.vcf.gz.done ]; then
		echo "INFO: Low GQ filter for ${CONTIG} already complete."
	else
		scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=LowQual_${PROJECT}_${CONTIG}
		cmd="srun gatk --java-options -Xmx12g \
			VariantFiltration \
			-R ${REFA} \
			-O ${PROJECT_PATH}/refinement/${CONTIG}_refine.vcf.gz \
			-V ${PROJECT_PATH}/applyrecal/${CONTIG}_recal.vcf.gz \
			-L ${CONTIG} \
			-G-filter \"GQ < 20.0\" \
			-G-filter-name lowGQ"
		mkdir -p ${PROJECT_PATH}/refinement/
		echo $cmd
		eval $cmd || exit 1$?
		mkdir -p ${PROJECT_PATH}/done/refinement
		touch ${PROJECT_PATH}/done/refinement/${CONTIG}_refine.vcf.gz.done
	fi
else
	if [ -f ${PROJECT_PATH}/done/refinement/${CONTIG}_post.vcf.gz.done ]; then
		echo "INFO: Posteriors for ${CONTIG} already complete."
	else
		scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=Posteriors_${PROJECT}_${CONTIG}
		cmd="srun gatk --java-options -Xmx68g \
			CalculateGenotypePosteriors \
			-R ${REFA} \
			-V ${PROJECT_PATH}/applyrecal/${CONTIG}_recal.vcf.gz \
			-L ${CONTIG} \
			${support} \
			-ped ${PROJECT_PATH}/ped.txt \
			--tmp-dir $TMPDIR \
			-O ${PROJECT_PATH}/refinement/${CONTIG}_post.vcf.gz"
		mkdir -p ${PROJECT_PATH}/refinement/
		echo $cmd
		eval $cmd || exit 1$?
		mkdir -p ${PROJECT_PATH}/done/refinement
		touch ${PROJECT_PATH}/done/refinement/${CONTIG}_post.vcf.gz.done
	fi
# GATK4 VariantAnnotator in beta and the PossibleDenovoAnnotation does not seem to be recognised
#	if [ -f ${PROJECT_PATH}/done/refinement/${CONTIG}_denovo.vcf.gz.done ]; then
#		echo "INFO: Posteriors for ${CONTIG} already complete."
#	else
#		scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=DeNovo_${PROJECT}_${CONTIG}
#			cmd="srun gatk --java-options -Xmx12g \
#			VariantAnnotator \
#			-R ${REFA} \
#			-A PossibleDeNovo \
#			-V ${PROJECT_PATH}/refinement/${CONTIG}_post.vcf.gz \
#			-L ${CONTIG} \
#			-ped ${PROJECT_PATH}/ped.txt \
#			-O ${PROJECT_PATH}/refinement/${CONTIG}_denovo.vcf.gz"
#			#-pedValidationType SILENT \
#		echo $cmd
#		eval $cmd || exit 1$?
#		touch ${PROJECT_PATH}/done/refinement/${CONTIG}_denovo.vcf.gz.done
#		if [ -f ${PROJECT_PATH}/refinement/${CONTIG}_post.vcf.gz ]; then
#			rm ${PROJECT_PATH}/refinement/${CONTIG}_post.vcf.gz
#		fi
#	fi
	if [ -f ${PROJECT_PATH}/done/refinement/${CONTIG}_refine.vcf.gz.done ]; then
		echo "INFO: Low Quality filtration for ${CONTIG} already complete."
	else
		scontrol update jobid=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} jobname=LowQual_${PROJECT}_${CONTIG}
		cmd="srun gatk --java-options -Xmx12g \
			VariantFiltration \
			-R ${REFA} \
			-O ${PROJECT_PATH}/refinement/${CONTIG}_refine.vcf.gz \
			-V ${PROJECT_PATH}/refinement/${CONTIG}_post.vcf.gz \
			-L ${CONTIG} \
			-G-filter \"GQ < 20.0\" \
			-G-filter-name lowGQ"
		echo $cmd
		eval $cmd || exit 1$?
		touch ${PROJECT_PATH}/done/refinement/${CONTIG}_refine.vcf.gz.done
		if [ -f ${PROJECT_PATH}/refinement/${CONTIG}_denovo.vcf.gz ]; then
			rm ${PROJECT_PATH}/refinement/${CONTIG}_denovo.vcf.gz
		fi
	fi
fi
if [ -f ${PROJECT_PATH}/applyrecal/${CONTIG}_recal.vcf.gz ]; then
	rm ${PROJECT_PATH}/applyrecal/${CONTIG}_recal.vcf.gz
fi
exit 0
