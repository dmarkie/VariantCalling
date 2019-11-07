#!/bin/bash

# This script is designed to take a collection of single-sample genomicVCF (g.vcf) files 
# containing SNV and Indel calls, and produce a multisample VCF using a workflow that is 
# largely consistent with GATK "best practise".

# The major outputs are a PrimaryCall VCF (standard multiallelic SNV and Indels calls for 
# a cohort of individuals) and a SplitMultiallelic VCF, which splits multiallelic variants 
# over two or more lines to represent them in a fashion that resembles "biallelic" varints.
# This format has some advantages for simplifying filtering commands. Not that individuals
# with sex chromosome aneusomies that have been processed to accurately represent ploidy, 
# will be excluded from the Split VCF file as the tool does not function for ploidy 
# greater than two. These individuals will be present in the PrimaryCall VCF. 

# The script requires information about paths to certain resources and some options, held 
# in the file config.sh.

# Once started this script will run interactively by requesting the full path to a 
# directory into which the final files will be placed, the directory does not need to 
# exist already. The name should be somewhat descriptive of the project or cohort and be 
# unique eg "20191027_Genomic_GATK". 

# If this is not a restart of a process that is partially completed it will then request:

# the g.vcf files to include in this process in the form of a samplemap file, which should
# contain all individuals to be included in this call. The format is a two-column tab 
# delimited file with sample IDs and full paths to the relevant g.vcf.gz file, one sample 
# per line.

# a pedigree file that includes an entry for all individuals in the cohort (but can 
# include others as well). This family information is used for genotype refinement, and 
# for producing the Mendelian Violation metrics.

# information regarding capture platform (if used) - the name of the capture platform
# should correspond to the basename of a bed file in the directory specified by the 
# PLATFORMS variable in the config.sh file

# information about whether gender was used in same way to fix the ploidy of the sex 
# chromosomes when undertaking the single sample call with HaplotypeCaller - this is 
# required to determine how to handle the X chromosome during the genotype refinement 
# process (it needs to be excluded if males are called as XY instead of XXYY) as  
# CalculateGenotypePosteriors can not handle monosomic regions

# If it is a restart, once it has determined the project name from the final directory,
# and recognised that it has already partially completed the processing, it will pick up
# the remaining information required and continue with the jobs that are yet to complete.

# The script will then:
# Generate a "Gender Report" by scraping information for each individual 
# from the coverage.sh file that is generated by the FastQ2VCF alignment pipeline. This 
# file needs to be present in the same directory as the g.vcf file for each individual 
# as identified in the sample map. The gender report will highlight any discrepancies 
# between reported and calculated (by coverage) gender, and identify any samples processed
# as sex chromosome aneusomies, that need to be excluded from the splitmultiallelic jobs.
 
# and set up slurm jobs with appropriate dependencies for:

# GenomeDBImport.sl
# GenomeDB groups the individual sample data (for each contig)

# genotypegvcf.sl
# Joint genotyping (for each contig) from the GenomeDB files.

# recalvcf.sl
# VQSR - Calculate Recalibration separately for SNP and INDEL, across the entire genome 
# using all contig files. Will also produce the plots for SNP and INDEL recalibration, and 
# the tranche histograms for SNP.

# applyrecal.sl
# VQSR - Apply Recalibration. Applies SNP recalibration first, then INDEL recalibration 
# (for each contig)

#refinement.sl
# Genotype Refinement (for each contig):
#	Calculates genotype posteriors based on available pedigree information and population 
#		(currently using Gnomad genomes 2.1)
#	Identifies possible de novo mutations using pedigree information when available 
#		loConf and hiConf (currently not working and disabled)
#	Adds a low quality genotype annotation for genotypes with a GQ less than 20
# For this part of the workflow, the True X region and the Y chromosome are generally 
# excluded from the first two steps as they do not work with non-diploid regions. If the X
# and Y chromosomes were uniformly called as diploid (for both males and females), the 
# answer to the question about using gender for the sex chromosome ploidy will be negative
# and the X and Y chromosomes will now be included in these steps.

# splitmultiallelic.sl
# Split multiallelics (for each contig) - this splits multiallelic variants into a "biallelic" 
# representation with one line for each ALT allele at a position. Because this currently 
# will not work for ploidy > 2, any sex chromosome aneusomies are excluded from the cohort 
# for this step - so they will be absent from the "SplitMultiallelics" vcf, but will still 
# be present in the "PrimaryCall" vcf

# merge.sl
# Merge contigs to produce a full vcf.gz file, containing multiallelic variant descriptions.

# mergesplit.sl
# Merge contigs to produce a full vcf.gz file, containing Split "biallelic" variant descriptions.

# mendelviol.sl
# Calculates Mendelian Violation stats for all trios in the cohort (according to the 
# pedigree file)

# move.sl 
# Transfers important files/directories from the working directory to the final 
# estination, makes a tarball of this script directory for future reference, removes the 
# majority of unnecessary files/directories from the working directory.

# clean.sl
# Transfers some remaining files before tarballing the working directory (to include the 
# slurm outputs files and the compressed script file) and sending to the final destination.
# Removes the working directory



export PBIN=$(dirname $0)
export SLSBIN=${PBIN}/slurm-scripts

source ${PBIN}/config.sh
source ${PBIN}/basefunctions.sh

############################################################
# Pick up some information for this particular variant call 

# final location to place output files - this should be the full path to a directory - if it doesn't already exist it will be made
if [ -z $1 ]; then
	while [ -z ${outputdir} ]; do
		(echo -e "\n\nSpecify a directory that will hold the final output files for this call. It will be created if it doesn't already exist.\n" 1>&2)
		read -e -p "Provide the full path for the directory, or q to quit, and press [RETURN]: " outputdir
		if [[ ${outputdir} == "q" ]]; then exit; fi;
	done
else
	${outputdir}=$1
fi
outputdir=$(echo "${outputdir}" | sed -e 's/\/$//')
export WORK_PATH="/scratch/$USER"
export PROJECT=$(basename ${outputdir})
export PROJECT_PATH=${WORK_PATH}/${PROJECT}
export parameterfile="${PROJECT_PATH}/parameters.sh"
export outputdir=${outputdir}

# if this is a restart, get the previously captured details here
if [ -f ${parameterfile} ]; then
	source ${parameterfile}
fi
# get the samplemap file
if [[ -z $2 ]]; then
	while [ -z ${samplemap} ] || [ ! -f ${samplemap} ]; do
		echo -e "\n\nSpecify which samples to include. These need to be supplied in a tab-delimited text file, with one sample name per line followed \nby the full path to a g.vcf.gz file containing a variant call for that sample. \n"
		read -e -p "Provide the name (and full path) of a file, or q to quit, and press [RETURN]: " samplemap
		if [[ ${samplemap} == "q" ]]; then exit; fi;
	done
else
	samplemap=$2 # the file that contains the list of g.vcf.gz files
fi

if [ -z ${PED} ]; then
	while [ -z ${PED} ] || [[ ! -f ${PED} ]]; do
		echo -e "\n\nProvide the pedigree file that includes this cohort of samples.\n"
		read -e -p "Type full path to the filename, or q to quit, and press [RETURN]: " PED
		if [[ ${PED} == "q" ]]; then exit; fi;
	done
fi
# pick up the users email address if not provided
# if [ -z ${email} ]; then email="walrus"; fi
# while [[ ${email} == "walrus" ]]; do
# 	echo -e "\n"
# 	read -e -p "Provide an email address for run notifications, leave blank to use your default address (if available), or type \"none\", or q to quit, and press [RETURN]: " email
# 	if [[ ${email} == "q" ]]; then exit; fi;
# done
# if [[ $email == "" ]]; then
# 	oldIFS=$IFS
# 	IFS=$'\n'
# 	userList=($(cat /etc/slurm/userlist.txt | grep $USER))
# 	for entry in ${userList[@]}; do
# 		testUser=$(echo $entry | awk -F':' '{print $1}')
# 		if [ "$testUser" == "$USER" ]; then
# 			export email=$(echo $entry | awk -F':' '{print $3}')
# 			break
# 		fi
# 	done
# 	IFS=$oldIFS
# 	if [ $email == "" ]; then
# 		(echo "FAIL: Unable to locate email address for $USER in /etc/slurm/userlist.txt!" 1>&2)
# 		exit 1
# 	else
# 		export MAIL_TYPE=FAIL,END
# 		(printf "%-22s%s (%s)\n" "Email address" "${email}" "$MAIL_TYPE" 1>&2)
# 	fi
# fi
# if [[ ${email} != "none" ]]; then
# 	mailme="--mail-user ${email} --mail-type FAIL,END"
# fi

# need to determine if there was a capture step during library construction, as this alters the annotations that are recommended for VQSR
if [ -z ${capture} ]; then
	while [[ $capture != "yes" ]] && [[ $capture != "no" ]]; do
		echo -e "\nWas a hybridisation capture step used (eg exome capture). This is important for determining the appropriate parameters for the VQSR step.\n"
		read -e -p "Enter yes or no, or q to quit, and press [RETURN]: " capture
		if [[ $capture == "q" ]]; then exit; fi
	done
fi
if [ "${capture}" == "yes" ]; then
# input an interval list defining the regions to include for VQSR - this is recommended if using exome capture data to improve the accuracy of VQSR scores - use the platform manifest and add 50 or 100 bp padding
	if [ -z ${vqsrinfile} ]; then
		platform=walrus
		while [ "$platform" == walrus ]; do
			echo -e "\nWould you like to restrict the Variant Quality Score Recalibration to a capture platform?\nThis is recommended if capture (eg exome) was used before sequencing."
			read -e -p "Provide the name of a capture platform, or nothing to continue with no restriction, or q to quit, and press [RETURN]: " platform
			if [[ $platform == "q" ]]; then exit; fi
		done
		if [ ! -z ${platform} ]; then
			vqsrinfile=${PLATFORMS}/${platform}.bed
		fi
	fi
	if [ ! -z $vqsrinfile ]; then
		if [ -z $vqsrinfilepadding ]; then
			vqsrinfilepadding="walrus"
			echo -e "\nWould you like to extend padding to your Variant Quality Score Recalibration interval list?"
			while [[ ! $vqsrinfilepadding =~ ^[0-9]+$ ]] && [[ ! -z $vqsrinfilepadding ]]; do
				read -e -p "Provide the number of base pairs to add, or nothing to continue with no padding, or q to quit, and press [RETURN]: " vqsrinfilepadding
				if [[ $vqsrinfilepadding == "q" ]]; then exit; fi
			done
		fi
	fi
fi

if [ -z ${sexchromosomes} ]; then
	while [[ ${sexchromosomes} != "yes" ]] && [[ ${sexchromosomes} != "no" ]]; do
		echo -e "\nWas gender (either reported or calculated) used to determine sex chromosome ploidy when generating the input g.vcfs?\n"
		read -e -p "Enter yes or no, or q to quit, and press [RETURN]: " sexchromosomes
		if [[ ${sexchromosomes} == "q" ]]; then exit; fi
	done
fi
export sexchromosomes=${sexchromosomes}

################################
# set up the working directory

mkdir -p ${PROJECT_PATH}
if [ ! -f ${PROJECT_PATH}/samplemap.txt ]; then
	cp ${samplemap} ${PROJECT_PATH}/samplemap.txt
fi
if [ ! -f ${PROJECT_PATH}/ped.txt ]; then
	cp ${PED} ${PROJECT_PATH}/ped.txt
	PED=${PROJECT_PATH}/ped.txt
fi
samplemap=${PROJECT_PATH}/samplemap.txt

# work out which directory we are launching from so that we can return to it for the final cleanup
launch=$PWD
cd ${PROJECT_PATH}

####################################
## Do the gender report here
if [ ! -f ${PROJECT_PATH}/done/master/${PROJECT}_GenderReport.txt.done ] && [ ${sexchromosomes} == "yes" ]; then
	mkdir -p ${PROJECT_PATH}/done/master
	echo -e "Subject\tReported\tDetermined\tChromosomes\tProcessed\tWarnings" > ${PROJECT_PATH}/${PROJECT}_GenderReport.txt
	for i in $(awk '{ print $1; }' ${samplemap} | sort -n | tr "\n" " "); do
#		(echo "Current ID: $i" 1>&2)
		coverage=$(dirname $(awk '$1 ~ /^'${i}'$/{ print $2; }' ${samplemap}))/*coverage.sh
		if [ ! -f ${coverage} ]; then
			(echo -e "ERROR: Can not find a coverage file for individual ${i} in $(dirname $(dirname ${coverage}))." 1>&2)
			exit 1
		fi
		reported=$(awk '$2 ~ /^'${i}'$/{ print $5; }' ${PED})
		reported=${reported,,} # Lower case
		reported=${reported:0:1} # First character only.
		if [ -z ${reported} ]; then
			(echo -e "ERROR: Can not find an entry for individual ${i} in file ${PED} to determine reported gender." 1>&2)
			exit 1
		elif [ "${reported}" == "m" ] || [ "${reported}" == "1" ]; then
			reportedgender=Male
		elif [ "${reported}" == "f" ] || [ "${reported}" == "2" ]; then
			reportedgender=Female
		elif [ "${reported}" -eq 0 ]; then
			reportedgender=Unknown
		else
			(echo -e "ERROR: The value ${reported} for ${i} in ${PED} does not match a gender definition." 1>&2)
			exit 1
		fi
		determinedgender=$(grep -m 1 "^#Gender:" ${coverage} | sed 's/^#Gender:[[:space:]]*\(.*\)$/\1/')
		sexchrom=$(grep -m 1 "#SexChr:" ${coverage} | sed 's/^#SexChr:[[:space:]]*\(.*\)$/\1/')
		alert1=""
		process=""
		if [ "${reportedgender}" != "${determinedgender}" ]; then
			alert1="ALERT: The determined gender does not match the reported gender."
		fi
		alert2=""
		if [ "${sexchrom}" != "XX" ] && [ "${sexchrom}" != "XY" ]; then
			alert2="ALERT: Detected sex chromosome anomaly."
		fi
		process=$(grep -m 1 "^#Processing as " ${coverage} | sed 's/^#Processing as \(.*\)$/\1/')
		if [ -z "${process}" ]; then
			process="${sexchrom}"
		fi
		(printf "Individual: %20s Reported: %7s Determined: %7s Sex Chr: %5s Processed as: %5s %s\n" ${i} ${reportedgender} ${determinedgender} ${sexchrom} ${process} "${alert1} ${alert2}" 1>&2)
		echo -e "${i}\t${reportedgender}\t${determinedgender}\t${sexchrom}\t${process}\t${alert1} ${alert2} "
	done >> ${PROJECT_PATH}/${PROJECT}_GenderReport.txt && \
	touch ${PROJECT_PATH}/done/master/${PROJECT}_GenderReport.txt.done
fi

#####################################################
# Store the collected information in a file to allow restart and ensure these values do not have to be re-entered - they should not change for a restart!
if [ ! -f ${PROJECT_PATH}/done/master/parameter.sh.done ]; then
	echo "email=\"${email}\"" >> ${parameterfile}
	echo "PED=\"${PED}\"" >> ${parameterfile}
	echo "capture=\"${capture}\"" >> ${parameterfile}
	echo "vqsrinfile=\"${vqsrinfile}\"" >> ${parameterfile}
	echo "vqsrinfilepadding=\"${vqsrinfilepadding}\"" >> ${parameterfile}
	echo "allelespecific=${allelespecific}" >> ${parameterfile}
	echo "CONTIGARRAY=(${CONTIGARRAY[@]})" >> ${parameterfile}
	echo "popdata=\"${popdata}\"" >> ${parameterfile}
	echo "outputdir=\"${outputdir}\"" >> ${parameterfile}
	echo "samplemap=\"${samplemap}\"" >> ${parameterfile}
	echo "REF=\"${REF}\"" >> ${parameterfile}
	echo "TRUEX=\"${TRUEX}\"" >> ${parameterfile}
	echo "DBSNP=\"${DBSNP}\"" >> ${parameterfile}
	echo "hapmapversion=\"${hapmapversion}\"" >> ${parameterfile}
	echo "omniversion=\"${omniversion}\"" >> ${parameterfile}
	echo "KGversion=\"${KGversion}\"" >> ${parameterfile}
	echo "millsversion=\"${millsversion}\"" >> ${parameterfile}
	echo "sexchromosomes=\"${sexchromosomes}\"" >> ${parameterfile}
	touch ${PROJECT_PATH}/done/master/parameter.sh.done
fi

####################################################
# Set up the slurm jobs

#### GenomicsDBimport

mkdir -p ${PROJECT_PATH}/slurm/GenomeDB
importArray=""
for i in $(seq 1 ${#CONTIGARRAY[@]}); do
	CONTIG=${CONTIGARRAY[$(( ${i} - 1 ))]}
    if [ ! -e ${PROJECT_PATH}/done/GenomeDB/GenomicsDBImport_${CONTIG}.done ]; then
         importArray=$(appendList "$importArray"  $i ",")
    fi
done

if [ "$importArray" != "" ]; then
	importjob=$(sbatch -J Import_${PROJECT} --array ${importArray}%6 ${mailme} ${SLSBIN}/GenomeDBimport.sl | awk '{print $4}')
	if [ $? -ne 0 ] || [ "$importjob" == "" ]; then
		(printf "FAILED!\n" 1>&2)
		exit 1
	else
		echo "Import_${PROJECT} job is ${importjob}"
		(printf "%sx%-4d [%s] Logs @ %s\n" "$importjob" $(splitByChar "$importArray" "," | wc -w) $(condenseList "$importArray") "${PROJECT_PATH}/slurm/GenomeDB/import-${importjob}_*.out" 1>&2)
	fi
fi

#####Joint Genotyping by contig

mkdir -p ${PROJECT_PATH}/slurm/genotype
genoArray=""
for i in $(seq 1 ${#CONTIGARRAY[@]}); do
	CONTIG=${CONTIGARRAY[$((${i}-1))]}
    if [ ! -e ${PROJECT_PATH}/done/genotype/${CONTIG}_gen.vcf.gz.done ]; then
         genoArray=$(appendList "$genoArray"  $i ",")
    fi
done

if [ "$genoArray" != "" ]; then
	genojob=$(sbatch -J Geno_${PROJECT} --array ${genoArray}%6 $(depCheck $importjob) ${mailme} ${SLSBIN}/genotypegvcf.sl | awk '{print $4}')
	if [ $? -ne 0 ] || [ "$genojob" == "" ]; then
		(printf "FAILED!\n" 1>&2)
		exit 1
	else
		echo "GenotypeGVCF_${PROJECT} job is ${genojob}"
		# Tie each task to the matching task in the previous array.
		tieTaskDeps "$genoArray" "$genojob" "$importArray" "$importjob"
		(printf "%sx%-4d [%s] Logs @ %s\n" "$genojob" $(splitByChar "$genoArray" "," | wc -w) $(condenseList "$genoArray") "${PROJECT_PATH}/slurm/genotype/ggvcf-${genojob}_*.out" 1>&2)
	fi
fi

##### VQSR: Calculate Recalibration (parallelised by MODE - SNP/INDEL)

mkdir -p ${PROJECT_PATH}/slurm/recalibrate

recalArray=""
count=0
for i in SNP INDEL; do
	count=$(( ${count} + 1 ))
    if [ ! -e ${PROJECT_PATH}/done/recalibrate/${i}output.recal.done ]; then
         recalArray=$(appendList "$recalArray"  ${count} ",")
    fi
done

if [ "$recalArray" != "" ]; then
	recaljob=$(sbatch $(depCheck $genojob) -J Recalibrator_${PROJECT} --array ${recalArray} ${mailme} ${SLSBIN}/recalvcf.sl | awk '{print $4}')
	if [ $? -ne 0 ] || [ "$recaljob" == "" ]; then
		(printf "FAILED!\n" 1>&2)
		exit 1
	else
		echo "Recalibrator_${PROJECT} job is ${recaljob}"
	fi
fi

#### VQSR: apply recalibration

mkdir -p ${PROJECT_PATH}/slurm/applyrecal
applyArray=""
for i in $(seq 1 ${#CONTIGARRAY[@]}); do
	CONTIG=${CONTIGARRAY[$((${i}-1))]}
    if [ ! -e ${PROJECT_PATH}/done/applyrecal/${CONTIG}_recal.vcf.gz.done ]; then
         applyArray=$(appendList "$applyArray"  $i ",")
    fi
done

if [ "$applyArray" != "" ]; then
	applyrecaljob=$(sbatch $(depCheck $recaljob) -J Applyrecal_${PROJECT} --array ${applyArray}%6 ${mailme} ${SLSBIN}/applyrecal.sl | awk '{print $4}')
	if [ $? -ne 0 ] || [ "$applyrecaljob" == "" ]; then
		(printf "FAILED!\n" 1>&2)
		exit 1
	else
		echo "Applyrecal_${PROJECT} job is ${applyrecaljob}"
		(printf "%s Log @ %s\n" "$applyrecaljob" "${PROJECT_PATH}/slurm/applyrecal/applyrecal-${applyrecaljob}.out" 1>&2)
	fi
fi

####### Genotype refinement
mkdir -p ${PROJECT_PATH}/slurm/refinement
refineArray=""
for i in $(seq 1 ${#CONTIGARRAY[@]}); do
	CONTIG=${CONTIGARRAY[$((${i}-1))]}
    if [ ! -e ${PROJECT_PATH}/done/refinement/${CONTIG}_refine.vcf.gz.done ]; then
         refineArray=$(appendList "$refineArray"  $i ",")
    fi
done
if [ "$refineArray" != "" ]; then
	refinejob=$(sbatch $(depCheck $applyrecaljob) -J Refine_${PROJECT} --array ${refineArray}%6 ${mailme} ${SLSBIN}/refinement.sl | awk '{print $4}')
	if [ $? -ne 0 ] || [ "$refinejob" == "" ]; then
		(printf "FAILED!\n" 1>&2)
		exit 1
	else
		echo "Refine_${PROJECT} job is ${refinejob}"
		# Tie each task to the matching task in the previous array.
		tieTaskDeps "$refineArray" "$refinejob" "$applyArray" "$applyrecaljob"
		(printf "%sx%-4d [%s] Logs @ %s\n" "$refinejob" $(splitByChar "$refineArray" "," | wc -w) $(condenseList "$refineArray") "${PROJECT_PATH}/slurm/refinement/refinement-${refinejob}_*.out" 1>&2)
	fi
fi

#### Split multiallelics for each contig
mkdir -p ${PROJECT_PATH}/slurm/split

splitArray=""
for i in $(seq 1 ${#CONTIGARRAY[@]}); do
	CONTIG=${CONTIGARRAY[$((${i}-1))]}
    if [ ! -e ${PROJECT_PATH}/done/split/${CONTIG}_Split.vcf.gz.tbi.done ]; then
         splitArray=$(appendList "$splitArray"  $i ",")
    fi
done
if [ "$splitArray" != "" ]; then
	splitjob=$(sbatch $(depCheck $refinejob) -J SplitMulti_${PROJECT} --array ${splitArray}%6 ${mailme} ${SLSBIN}/splitmultiallelic.sl | awk '{print $4}')
	if [ $? -ne 0 ] || [ "$splitjob" == "" ]; then
		(printf "FAILED!\n" 1>&2)
		exit 1
	else
		echo "SplitMulti_${PROJECT} job is ${splitjob}"
		# Tie each task to the matching task in the previous array.
		tieTaskDeps "$splitArray" "$splitjob" "$refineArray" "$refinejob"
		(printf "%sx%-4d [%s] Logs @ %s\n" "$splitjob" $(splitByChar "$splitArray" "," | wc -w) $(condenseList "$splitArray") "${PROJECT_PATH}/slurm/split/split-${splitjob}_*.out" 1>&2)
	fi
fi

#### Merge the unsplit contig vcf.gz files together, dependent on afterok:${refinejob}
mkdir -p ${PROJECT_PATH}/slurm/merge

if [ ! -f "${PROJECT_PATH}/done/merge/${PROJECT}_ID.list.done" ]; then
	mergejob=$(sbatch $(depCheck $refinejob) -J Merge_${PROJECT} ${mailme} ${SLSBIN}/merge.sl | awk '{print $4}')
	if [ $? -ne 0 ] || [ "$mergejob" == "" ]; then
		(printf "FAILED!\n" 1>&2)
		exit 1
	else
		echo "Merge_${PROJECT} job is ${mergejob}"
		(printf "%s Log @ %s\n" "$mergejob" "${PROJECT_PATH}/slurm/merge/merge-${mergejob}.out" 1>&2)
	fi
fi

#### Mendelian violations report -dependent on merge of unsplit contigs only
mkdir -p ${PROJECT_PATH}/slurm/mendelviol
if [ ! -f "${PROJECT_PATH}/done/mendelviol/${PROJECT}_MendelianViolations.txt.done" ]; then
	mendelvioljob=$(sbatch $(depCheck $mergejob) -J MendelViol_${PROJECT} ${mailme} ${SLSBIN}/mendelviol.sl ${PROJECT_PATH}/merge/${PROJECT}.vcf.gz ${PED} | awk '{print $4}')
	if [ $? -ne 0 ] || [ "$mendelvioljob" == "" ]; then
		(printf "FAILED!\n" 1>&2)
		exit 1
	else
		echo "MendelViol_${PROJECT} job is ${mendelvioljob}"
		(printf "%s Log @ %s\n" "$mendelvioljob" "${PROJECT_PATH}/slurm/mendelviol/viol-${mendelvioljob}.out" 1>&2)
	fi
fi

#### Merge split dependent on split jobs completing
mkdir -p ${PROJECT_PATH}/slurm/mergesplit
if [ ! -f "${PROJECT_PATH}/done/mergesplit/${PROJECT}_Split_ID.list.done" ]; then
	mergesplitjob=$(sbatch $(depCheck $splitjob) -J Merge_Split_${PROJECT} ${mailme} ${SLSBIN}/mergesplit.sl | awk '{print $4}')
	if [ $? -ne 0 ] || [ "$mergesplitjob" == "" ]; then
		(printf "FAILED!\n" 1>&2)
		exit 1
	else
		echo "Merge_Split_${PROJECT} job is ${mergesplitjob}"
		(printf "%s Log @ %s\n" "$mergesplitjob" "${PROJECT_PATH}/slurm/mergesplit/mergesplit-${mergesplitjob}.out" 1>&2)
	fi
fi

#### Package up script, move critical files - dependent on mergesplit and mendelian violations completing
mkdir -p ${PROJECT_PATH}/slurm/move

if [ ! -f "${PROJECT_PATH}/done/move/directoriesremoved.done" ]; then
	movejob=$(sbatch $(depCheck ${mergesplitjob}) -J Move_${PROJECT} ${mailme} ${SLSBIN}/move.sl | awk '{print $4}')
	if [ $? -ne 0 ] || [ "$movejob" == "" ]; then
		(printf "FAILED!\n" 1>&2)
		exit 1
	else
		echo "Move_${PROJECT} job is ${movejob}"
		(printf "%s Log @ %s\n" "$movejob" "${PROJECT_PATH}/slurm/move/move-${movejob}.out" 1>&2)
	fi
fi

# move back to the launch directory for final cleanup and removal
cd ${launch}

### cleanup - package up slurm directory and move, remove project directory
if [ "${movejob}" != "" ] && [ "${mendelvioljob}" != "" ]; then
	depend="--dependency=afterok:${movejob}:${mendelvioljob}"
elif [ "${movejob}" != "" ]; then
	depend="--dependency=afterok:${movejob}"
elif [ "${mendelvioljob}" != "" ]; then
	depend="--dependency=afterok:${mendelvioljob}"
else
	depend=""
fi

cleanjob=$(sbatch ${depend} -J Clean_${PROJECT} ${mailme} ${SLSBIN}/clean.sl | awk '{print $4}')
echo "Clean_${PROJECT} job is ${cleanjob}"
