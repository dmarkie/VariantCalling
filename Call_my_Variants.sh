#!/bin/bash

# It requires a samplemap file at startup which is a tab delimted file with sample IDs and full paths to the relevant g.vcf.gz file, one sample per line  
# This script should set up jobs for:

# genotypegvcf.sl
# GenomeDB groups the individual sample data (for each contig)
# Joint genotyping. 

# recalvcf.sl
# VQSR - Calculate Recalibration separately for SNP and INDEL, across the entire genome using all contig files. 
# Will also produce the plots for SNP and INDEL recalibration, and the tranche histograms for SNP.

# applyrecal.sl
# VQSR - Apply Recalibration. Applies SNP recalibration first, then INDEL recalibration oneach contig
# Genotype Refinement: 
#	Calculates genotype posteriors based on available pedigree information and population (currently using Gnomad genomes)
#	Identifies possible de novo mutations using pedigree information when available loConf and hiConf
#	Adds a low quality genotype annotation for genotypes with a GQ less than 20
# For this workflow, the True X region and the Y chromosome are excluded from the first two steps as they do not work with non-diploid regions.
# Therefore the True X region and the Y chromosome have not had their genotypes improved, and have not been called and annotated for de novos - 
# de novo calling will need to be done independently and specifically for each trio.

# Split multiallelics

# Merge contigs together to produce a full unannotated multi-sample vcf.gz file.


#################################################################################################
# some useful functions from Sam's baserefs.sh

#####################
# Return a string with a new item on the end
# Items are separated by a char or space
#####################
function appendList {
        oldList="${1}"
        newItem="${2}"
        itemJoiner=$([ "${3}" == "" ] && echo -ne " " || echo -ne "${3}")       # If blank, use space.
        if [ "$newItem" != "" ]; then
                if [ "$oldList" == "" ]; then
                        # Initial Entry
                        printf "%s" "$newItem"
                else
                        # Additional Entry
                        printf "%s%s%s" "$oldList" "$itemJoiner" "$newItem"
                fi
        else
                printf "%s" "$oldList"
        fi
}
export -f appendList

###################
# Outputs a dependency if one exists.
###################
function depCheck {
	#(echo "depCheck: $0 \"${@}\"" | tee -a ~/depCheck.txt 1>&2)
	local jobList=$(jobsExist "$1")
	[ "$jobList" != "" ] && echo -ne "--dependency afterok:${jobList}"
}
export -f depCheck

####################
# Returns true if the list of jobs passed are running or waiting to run, otherwise false
####################
function jobsExist {
	local jobList=""
	local IFS=':'
	for item in $@
	do
		if squeue -j $item | grep "$item" &>/dev/null
		then
			jobList=$(appendList "$jobList" $item ":")
		fi
	done
	echo "$jobList"
}
export -f jobsExist

###################
# Visual ticker
###################
function tickOver {
	case "$TICKER" in
		"|") TICKER="/" ;;
		"/") TICKER="-" ;;
		"-") TICKER="\\" ;;
		*) TICKER="|" ;;
	esac
	
	>&2 printf "%s\b" "$TICKER"
}
export -f tickOver

#######################
# Condenses list of numbers to ranges
#
# 1,2,3,4,7,8,9,12,13,14 -> 1-3,4,7-9,12-14
#######################
function condenseList {
	echo "${@}," | \
		sed "s/,/\n/g" | \
		while read num
		do
		if [[ -z $first ]]
		then
			first=$num
			last=$num
			continue
		fi
		if [[ num -ne $((last + 1)) ]]
		then
			if [[ first -eq last ]]
			then
				echo $first
			else
				echo $first-$last
			fi
			first=$num
			last=$num
		else
			: $((last++))
		fi
	done | paste -sd ","
}
export -f condenseList

#####################
# Expand comma separated list of ranges to individual elements
#
# 1,3-5,8,10-12 -> 1,3,4,5,8,10,11,12
#####################
function expandList {
	for f in ${1//,/ }; do
		if [[ $f =~ - ]]; then
			a+=( $(seq ${f%-*} 1 ${f#*-}) )
		else
			a+=( $f )
		fi  
	done
	
	a=${a[*]}
	a=${a// /,}
	
	echo $a
}
export -f expandList

######################
# Return the string with the split char replaced by a space
######################
function splitByChar {
	input=${1}
	char=${2}
	
	if [ "$char" != "" ]; then
		echo -ne "$input" | sed -e "s/${char}/ /g"
	else
		echo -ne "FAIL"
		(>&2 echo -ne "FAILURE:\t splitByChar [${1}] [${2}]\n\tNo character to replace. You forget to quote your input?\n")
	fi
}
export -f splitByChar

######################
# Find matching task elements in a parent and child array.
# Set the child array task element to be dependent on the matching parent task element.
######################
function tieTaskDeps {
	childArray=$(expandList ${1})
	childJobID=${2}
	parentArray=$(expandList ${3})
	parentJobID=${4}
	
	if [ "$childArray" != "" ] && [ "$parentArray" != "" ]; then
		# Both arrays contain something.
		# Cycle through child array elements
		for i in $(splitByChar "$childArray" ","); do
			elementMatched=0
			# Cycle through parent array elements.
			for j in $(splitByChar "$parentArray" ","); do
				if [ "$i" == "$j" ]; then
					# Matching element found. Tie child element to parent element.
#					printf " T[%s->%s] " "${childJobID}_$i" "${parentJobID}_$j"
					scontrol update JobId=${childJobID}_$i Dependency=afterok:${parentJobID}_$j
					elementMatched=1
				fi
			done
			if [ $elementMatched -eq 0 ]; then
				# No matching element found in parent array.
				# Release child element from entire parent array.
				scontrol update JobId=${childJobID}_$i Dependency=
			fi
			tickOver
		done
	fi
}
export -f tieTaskDeps


# the following need to be defined:
# the full path to the reference sequence to be used - without extension. The .fasta and .dict files for this reference should be found in this location
export REF="/resource/bundles/broad_bundle_b37_v2.5/human_g1k_v37"
export REFA=${REF}.fasta
export REFD=${REF}.dict
# the co-ordinates for the true x region for the above reference - should be found in the Genome Reference Consortium site
export TRUEX="X:2699521-154931043"
# the dbsnp data to be used (providing variant ID and for VQSR)
export DBSNP="/resource/bundles/broad_bundle_b37_v2.5/dbsnp_137.b37.vcf"
# the hap map data to use (for VQSR)
export hapmapversion="/resource/bundles/broad_bundle_b37_v2.5/hapmap_3.3.b37.vcf"
# the omni data to use (for VQSR)
export omniversion="/resource/bundles/broad_bundle_b37_v2.5/1000G_omni2.5.b37.vcf"
# the 1000 genomes data to use (for VQSR)
export KGversion="/resource/bundles/broad_bundle_b37_v2.5/1000G_phase3_v4_20130502.sites.vcf"
# the high quality indel data to use (for VQSR)
export millsversion="/resource/bundles/broad_bundle_b37_v2.5/Mills_and_1000G_gold_standard.indels.b37.vcf"
# population data for calculating genotype posteriors
export popdata="/resource/bundles/REgnomAD/2.1/Genomes/gnomad.genomes.r2.1.sites.vcf.gz"
export PBIN=$(dirname $0)
export SLSBIN=${PBIN}/slurm-scripts
export PLATFORMS=/resource/bundles/Capture_Platforms/GRCh37
#export NUMCONTIGS=${#CONTIGARRAY[@]}
#export NUMAUTOCONTIGS=${#AUTOSOMEARRAY[@]}
# the following variable determines how the X chromosome is processed. If it is "whole" then it will not be split up for the genotype refinement, and there will be no calculation of genotype posteriors or de novos for any of the X chromosome. This is essential if there are any X chromosome aneusomies in the cohort (eg XXX, XXY, X0) as those tools only work on disomic data. If this variable is set to anything else the XPAR regions will be processed through the full genotype refinement, but the True X will not
export XPROC="whole"
#################################################################################################

# this is probably a better version of 349 ungapped regions from https://github.com/oskarvid/wdl_germline_pipeline/blob/master/intervals/intervals_hg19.interval_list - this one appears to break whenever there is one or more Ns
#CONTIGARRAY=(1:10001-177417 1:227418-267719 1:317720-471368 1:521369-2634220 1:2684221-3845268 1:3995269-13052998 1:13102999-13219912 1:13319913-13557162 1:13607163-17125658 1:17175659-29878082 1:30028083-103863906 1:103913907-120697156 1:120747157-120936695 1:121086696-121485434 1:142535435-142731022 1:142781023-142967761 1:143117762-143292816 1:143342817-143544525 1:143644526-143771002 1:143871003-144095783 1:144145784-144224481 1:144274482-144401744 1:144451745-144622413 1:144672414-144710724 1:144810725-145833118 1:145883119-146164650 1:146214651-146253299 1:146303300-148026038 1:148176039-148361358 1:148511359-148684147 1:148734148-148954460 1:149004461-149459645 1:149509646-205922707 1:206072708-206332221 1:206482222-223747846 1:223797847-235192211 1:235242212-248908210 1:249058211-249240621 2:10001-3529312 2:3579313-5018788 2:5118789-16279724 2:16329725-21153113 2:21178114-31725939 2:31726791-33092197 2:33093198-33141692 2:33142693-87668206 2:87718207-89630436 2:89830437-90321525 2:90371526-90545103 2:91595104-92326171 2:95326172-110109337 2:110251338-149690582 2:149790583-234003741 2:234053742-239801978 2:239831979-240784132 2:240809133-243102476 2:243152477-243189373 3:60001-66170270 3:66270271-90504854 3:93504855-194041961 3:194047252-197962430 4:10001-1423146 4:1478647-8799203 4:8818204-9274642 4:9324643-31820917 4:31837418-32834638 4:32840639-40296396 4:40297097-49338941 4:49488942-49660117 4:52660118-59739333 4:59789334-75427379 4:75452280-191044276 5:10001-17530657 5:17580658-46405641 5:49405642-91636128 5:91686129-138787073 5:138837074-155138727 5:155188728-180905260 6:60001-58087659 6:58137660-58780166 6:61880167-62128589 6:62178590-95680543 6:95830544-157559467 6:157609468-157641300 6:157691301-167942073 6:168042074-170279972 6:170329973-171055067 7:10001-232484 7:282485-50370631 7:50410632-58054331 7:61054332-61310513 7:61360514-61460465 7:61510466-61677020 7:61727021-61917157 7:61967158-74715724 7:74765725-100556043 7:100606044-130154523 7:130254524-139379377 7:139404378-142048195 7:142098196-142276197 7:142326198-143347897 7:143397898-154270634 7:154370635-159128663 8:10001-7474649 8:7524650-12091854 8:12141855-43838887 8:46838888-48130499 8:48135600-86576451 8:86726452-142766515 8:142816516-145332588 8:145432589-146304022 9:10001-39663686 9:39713687-39974796 9:40024797-40233029 9:40283030-40425834 9:40475835-40940341 9:40990342-41143214 9:41193215-41365793 9:41415794-42613955 9:42663956-43213698 9:43313699-43946569 9:43996570-44676646 9:44726647-44908293 9:44958294-45250203 9:45350204-45815521 9:45865522-46216430 9:46266431-46461039 9:46561040-47060133 9:47160134-47317679 9:65467680-65918360 9:65968361-66192215 9:66242216-66404656 9:66454657-66614195 9:66664196-66863343 9:66913344-67107834 9:67207835-67366296 9:67516297-67987998 9:68137999-68514181 9:68664182-68838946 9:68988947-69278385 9:69328386-70010542 9:70060543-70218729 9:70318730-70506535 9:70556536-70735468 9:70835469-92343416 9:92443417-92528796 9:92678797-133073060 9:133223061-137041193 9:137091194-139166997 9:139216998-141153431 10:60001-17974675 10:18024676-38818835 10:38868836-39154935 10:42354936-42546687 10:42596688-46426964 10:46476965-47429169 10:47529170-47792476 10:47892477-48055707 10:48105708-49095536 10:49195537-51137410 10:51187411-51398845 10:51448846-54900228 10:54900231-125869472 10:125919473-128616069 10:128766070-133381404 10:133431405-133677527 10:133727528-135524747 11:60001-1162759 11:1212760-50783853 11:51090854-51594205 11:54694206-69089801 11:69139802-69724695 11:69774696-87688378 11:87738379-96287584 11:96437585-134946516 12:60001-95739 12:145740-7189876 12:7239877-34856694 12:37856695-109373470 12:109423471-121965036 12:121965237-122530623 12:122580624-123928080 12:123928281-123960721 12:123960822-132706992 12:132806993-133841895 13:19020001-86760324 13:86910325-112353994 13:112503995-114325993 13:114425994-114639948 13:114739949-115109878 14:19000001-107289540 15:20000001-20894633 15:20935076-21398819 15:21885001-22212114 15:22262115-22596193 15:22646194-23514853 15:23564854-27591204 15:27591207-29159443 15:29209444-82829645 15:82879646-84984473 15:85034474-102521392 16:60001-8636921 16:8686922-34023150 16:34173151-35285801 16:46385802-88389383 16:88439384-90294753 17:1-296626 17:396627-21566608 17:21666609-22263006 17:25263007-34675848 17:34725849-62410760 17:62460761-77546461 17:77596462-79709049 17:79759050-81195210 18:10001-15410898 18:18510899-52059136 18:52209137-72283353 18:72333354-75721820 18:75771821-78013485 18:78013490-78013508 18:78013511-78013525 18:78013528-78017248 19:60001-7346004 19:7396005-8687198 19:8737199-20523415 19:20573416-24631782 19:27731783-59118983 20:60001-26319569 20:29419570-29653908 20:29803909-34897085 20:34947086-61091437 20:61141438-61213369 20:61263370-62965520 21:9411194-9595548 21:9645549-9775437 21:9825438-10034920 21:10084921-10215976 21:10365977-10647896 21:10697897-11188129 21:14338130-33157035 21:33157056-33157379 21:33157390-40285944 21:40285955-42955559 21:43005560-43226828 21:43227329-43249342 21:43250843-44035894 21:44035905-44632664 21:44682665-44888040 21:44888051-48119895 22:16050001-16697850 22:16847851-19178161 22:19178165-19178165 22:19178168-20509431 22:20609432-50364777 22:50414778-51244566 X:60001-94821 X:144822-231384 X:281385-1047557 X:1097558-1134113 X:1184114-1264234 X:1314235-2068238 X:2118239-7623882 X:7673883-10738674 X:10788675-37098256 X:37148257-49242997 X:49292998-49974173 X:50024174-52395914 X:52445915-58582012 X:61682013-76653692 X:76703693-113517668 X:113567669-115682290 X:115732291-120013235 X:120063236-143507324 X:143557325-148906424 X:148956425-149032062 X:149082063-152277099 X:152327100-155260560 Y:2649521-8914955 Y:8964956-9241322 Y:9291323-10104553 Y:13104554-13143954 Y:13193955-13748578 Y:13798579-20143885 Y:20193886-22369679 Y:22419680-23901428 Y:23951429-28819361 Y:58819362-58917656 Y:58967657-59034049 GL000207.1:1-4262 GL000226.1:1-15008 GL000229.1:1-19913 GL000231.1:1-27386 GL000210.1:1-9933 GL000210.1:10034-27682 GL000239.1:1-33824 GL000235.1:1-34474 GL000201.1:1-36148 GL000247.1:1-36422 GL000245.1:1-36651 GL000197.1:1-23053 GL000197.1:23154-37175 GL000203.1:1-37498 GL000246.1:1-38154 GL000249.1:1-38502 GL000196.1:1-38914 GL000248.1:1-39786 GL000244.1:1-39929 GL000238.1:1-39939 GL000202.1:1-40103 GL000234.1:1-40531 GL000232.1:1-40652 GL000206.1:1-41001 GL000240.1:1-41933 GL000236.1:1-41934 GL000241.1:1-42152 GL000243.1:1-43341 GL000242.1:1-43523 GL000230.1:1-43691 GL000237.1:1-45867 GL000233.1:1-45941 GL000204.1:1-81310 GL000198.1:1-90085 GL000208.1:1-92689 GL000191.1:1-106433 GL000227.1:1-128374 GL000228.1:1-129120 GL000214.1:1-137718 GL000221.1:1-155397 GL000209.1:1-159169 GL000218.1:1-161147 GL000220.1:1-161802 GL000213.1:1-164239 GL000211.1:1-166566 GL000199.1:1-169874 GL000217.1:1-172149 GL000216.1:1-172294 GL000215.1:1-172545 GL000205.1:1-174588 GL000219.1:1-179198 GL000224.1:1-179693 GL000223.1:1-180455 GL000195.1:1-182896 GL000212.1:1-186858 GL000222.1:1-186861 GL000200.1:1-187035 GL000193.1:1-189789 GL000194.1:1-191469 GL000225.1:1-211173 GL000192.1:1-547496)

#this one is generated by the following commands, which takes human_g1k_v37 reference and splits it wherever there are ten or more Ns, to generate 338 ungapped contigs
#module load GATK4; gatk ScatterIntervalsByNs -R /resource/bundles/broad_bundle_b37_v2.5/human_g1k_v37.fasta -O interval.list -N 10 -OT ACGT 
#echo -e "CONTIGARRAY=($(grep -v "^[@|MT]" interval.list | awk '{print $1":"$2"-"$3}' | tr "\n" " "))"
CONTIGARRAY=(1:10001-177417 1:227418-267719 1:317720-471368 1:521369-2634220 1:2684221-3845268 1:3995269-13052998 1:13102999-13219912 1:13319913-13557162 1:13607163-17125658 1:17175659-29878082 1:30028083-103863906 1:103913907-120697156 1:120747157-120936695 1:121086696-121485434 1:142535435-142731022 1:142781023-142967761 1:143117762-143292816 1:143342817-143544525 1:143644526-143771002 1:143871003-144095783 1:144145784-144224481 1:144274482-144401744 1:144451745-144622413 1:144672414-144710724 1:144810725-145833118 1:145883119-146164650 1:146214651-146253299 1:146303300-148026038 1:148176039-148361358 1:148511359-148684147 1:148734148-148954460 1:149004461-149459645 1:149509646-205922707 1:206072708-206332221 1:206482222-223747846 1:223797847-235192211 1:235242212-248908210 1:249058211-249240621 2:10001-3529312 2:3579313-5018788 2:5118789-16279724 2:16329725-21153113 2:21178114-31725939 2:31726791-33092197 2:33093198-33141692 2:33142693-87668206 2:87718207-89630436 2:89830437-90321525 2:90371526-90545103 2:91595104-92326171 2:95326172-110109337 2:110251338-149690582 2:149790583-234003741 2:234053742-239801978 2:239831979-240784132 2:240809133-243102476 2:243152477-243189373 3:60001-66170270 3:66270271-90504854 3:93504855-194041961 3:194047252-197962430 4:10001-1423146 4:1478647-8799203 4:8818204-9274642 4:9324643-31820917 4:31837418-32834638 4:32840639-40296396 4:40297097-49338941 4:49488942-49660117 4:52660118-59739333 4:59789334-75427379 4:75452280-191044276 5:10001-17530657 5:17580658-46405641 5:49405642-91636128 5:91686129-138787073 5:138837074-155138727 5:155188728-180905260 6:60001-58087659 6:58137660-58780166 6:61880167-62128589 6:62178590-95680543 6:95830544-157559467 6:157609468-157641300 6:157691301-167942073 6:168042074-170279972 6:170329973-171055067 7:10001-232484 7:282485-50370631 7:50410632-58054331 7:61054332-61310513 7:61360514-61460465 7:61510466-61677020 7:61727021-61917157 7:61967158-74715724 7:74765725-100556043 7:100606044-130154523 7:130254524-139379377 7:139404378-142048195 7:142098196-142276197 7:142326198-143347897 7:143397898-154270634 7:154370635-159128663 8:10001-7474649 8:7524650-12091854 8:12141855-43838887 8:46838888-48130499 8:48135600-86576451 8:86726452-142766515 8:142816516-145332588 8:145432589-146304022 9:10001-39663686 9:39713687-39974796 9:40024797-40233029 9:40283030-40425834 9:40475835-40940341 9:40990342-41143214 9:41193215-41365793 9:41415794-42613955 9:42663956-43213698 9:43313699-43946569 9:43996570-44676646 9:44726647-44908293 9:44958294-45250203 9:45350204-45815521 9:45865522-46216430 9:46266431-46461039 9:46561040-47060133 9:47160134-47317679 9:65467680-65918360 9:65968361-66192215 9:66242216-66404656 9:66454657-66614195 9:66664196-66863343 9:66913344-67107834 9:67207835-67366296 9:67516297-67987998 9:68137999-68514181 9:68664182-68838946 9:68988947-69278385 9:69328386-70010542 9:70060543-70218729 9:70318730-70506535 9:70556536-70735468 9:70835469-92343416 9:92443417-92528796 9:92678797-133073060 9:133223061-137041193 9:137091194-139166997 9:139216998-141153431 10:60001-17974675 10:18024676-38818835 10:38868836-39154935 10:42354936-42546687 10:42596688-46426964 10:46476965-47429169 10:47529170-47792476 10:47892477-48055707 10:48105708-49095536 10:49195537-51137410 10:51187411-51398845 10:51448846-125869472 10:125919473-128616069 10:128766070-133381404 10:133431405-133677527 10:133727528-135524747 11:60001-1162759 11:1212760-50783853 11:51090854-51594205 11:54694206-69089801 11:69139802-69724695 11:69774696-87688378 11:87738379-96287584 11:96437585-134946516 12:60001-95739 12:145740-7189876 12:7239877-34856694 12:37856695-109373470 12:109423471-121965036 12:121965237-122530623 12:122580624-123928080 12:123928281-123960721 12:123960822-132706992 12:132806993-133841895 13:19020001-86760324 13:86910325-112353994 13:112503995-114325993 13:114425994-114639948 13:114739949-115109878 14:19000001-107289540 15:20000001-20894633 15:20935076-21398819 15:21885001-22212114 15:22262115-22596193 15:22646194-23514853 15:23564854-29159443 15:29209444-82829645 15:82879646-84984473 15:85034474-102521392 16:60001-8636921 16:8686922-34023150 16:34173151-35285801 16:46385802-88389383 16:88439384-90294753 17:1-296626 17:396627-21566608 17:21666609-22263006 17:25263007-34675848 17:34725849-62410760 17:62460761-77546461 17:77596462-79709049 17:79759050-81195210 18:10001-15410898 18:18510899-52059136 18:52209137-72283353 18:72333354-75721820 18:75771821-78017248 19:60001-7346004 19:7396005-8687198 19:8737199-20523415 19:20573416-24631782 19:27731783-59118983 20:60001-26319569 20:29419570-29653908 20:29803909-34897085 20:34947086-61091437 20:61141438-61213369 20:61263370-62965520 21:9411194-9595548 21:9645549-9775437 21:9825438-10034920 21:10084921-10215976 21:10365977-10647896 21:10697897-11188129 21:14338130-33157035 21:33157056-42955559 21:43005560-43226828 21:43227329-43249342 21:43250843-44632664 21:44682665-48119895 22:16050001-16697850 22:16847851-20509431 22:20609432-50364777 22:50414778-51244566 X:60001-94821 X:144822-231384 X:281385-1047557 X:1097558-1134113 X:1184114-1264234 X:1314235-2068238 X:2118239-7623882 X:7673883-10738674 X:10788675-37098256 X:37148257-49242997 X:49292998-49974173 X:50024174-52395914 X:52445915-58582012 X:61682013-76653692 X:76703693-113517668 X:113567669-115682290 X:115732291-120013235 X:120063236-143507324 X:143557325-148906424 X:148956425-149032062 X:149082063-152277099 X:152327100-155260560 Y:2649521-8914955 Y:8964956-9241322 Y:9291323-10104553 Y:13104554-13143954 Y:13193955-13748578 Y:13798579-20143885 Y:20193886-22369679 Y:22419680-23901428 Y:23951429-28819361 Y:58819362-58917656 Y:58967657-59034049 GL000207.1:1-4262 GL000226.1:1-15008 GL000229.1:1-19913 GL000231.1:1-27386 GL000210.1:1-9933 GL000210.1:10034-27682 GL000239.1:1-33824 GL000235.1:1-34474 GL000201.1:1-36148 GL000247.1:1-36422 GL000245.1:1-36651 GL000197.1:1-23053 GL000197.1:23154-37175 GL000203.1:1-37498 GL000246.1:1-38154 GL000249.1:1-38502 GL000196.1:1-38914 GL000248.1:1-39786 GL000244.1:1-39929 GL000238.1:1-39939 GL000202.1:1-40103 GL000234.1:1-40531 GL000232.1:1-40652 GL000206.1:1-41001 GL000240.1:1-41933 GL000236.1:1-41934 GL000241.1:1-42152 GL000243.1:1-43341 GL000242.1:1-43523 GL000230.1:1-43691 GL000237.1:1-45867 GL000233.1:1-45941 GL000204.1:1-81310 GL000198.1:1-90085 GL000208.1:1-92689 GL000191.1:1-106433 GL000227.1:1-128374 GL000228.1:1-129120 GL000214.1:1-137718 GL000221.1:1-155397 GL000209.1:1-159169 GL000218.1:1-161147 GL000220.1:1-161802 GL000213.1:1-164239 GL000211.1:1-166566 GL000199.1:1-169874 GL000217.1:1-172149 GL000216.1:1-172294 GL000215.1:1-172545 GL000205.1:1-174588 GL000219.1:1-179198 GL000224.1:1-179693 GL000223.1:1-180455 GL000195.1:1-182896 GL000212.1:1-186858 GL000222.1:1-186861 GL000200.1:1-187035 GL000193.1:1-189789 GL000194.1:1-191469 GL000225.1:1-211173 GL000192.1:1-547496 )
#This one will use the "chromosome" contigs from the reference
#CONTIGARRAY=($(cat $REFD | awk 'NR!=1{print $2}' | sed -e 's/SN://g' | grep -v "MT"))

## Make a banner describing what the script does and declaring the variables above, and the scripts requiring access

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
# if this is a restart, pick up the details here
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
if [ -z ${email} ]; then email="walrus"; fi
while [[ ${email} == "walrus" ]]; do
	echo -e "\n"
	read -e -p "Provide an email address for run notifications, leave blank to use your default address, or type \"none\", or q to quit, and press [RETURN]: " email
	if [[ ${email} == "q" ]]; then exit; fi;
done
if [[ $email == "" ]]; then
	oldIFS=$IFS
	IFS=$'\n'
	userList=($(cat /etc/slurm/userlist.txt | grep $USER))
	for entry in ${userList[@]}; do
		testUser=$(echo $entry | awk -F':' '{print $1}')
		if [ "$testUser" == "$USER" ]; then
			export email=$(echo $entry | awk -F':' '{print $3}')
			break
		fi
	done
	IFS=$oldIFS
	if [ $email == "" ]; then
		(echo "FAIL: Unable to locate email address for $USER in /etc/slurm/userlist.txt!" 1>&2)
		exit 1
	else
		export MAIL_TYPE=FAIL,END
		(printf "%-22s%s (%s)\n" "Email address" "${email}" "$MAIL_TYPE" 1>&2)
	fi
fi
if [[ ${email} != "none" ]]; then
	mailme="--mail-user ${email} --mail-type FAIL,END"
fi


export allelespecific="yes"

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
		echo -e "\nWas the reported gender or calculated sex chromosome coverage used to call genotypes?\n"
		read -e -p "Enter yes or no, or q to quit, and press [RETURN]: " sexchromosomes
		if [[ ${sexchromosomes} == "q" ]]; then exit; fi
	done
fi
export sexchromosomes=${sexchromosomes}

mkdir -p ${PROJECT_PATH}
if [ ! -f ${PROJECT_PATH}/samplemap.txt ]; then
	cp ${samplemap} ${PROJECT_PATH}/samplemap.txt
fi
if [ ! -f ${PROJECT_PATH}/ped.txt ]; then
	cp ${PED} ${PROJECT_PATH}/ped.txt
	PED=${PROJECT_PATH}/ped.txt
fi

samplemap=${PROJECT_PATH}/samplemap.txt
launch=$PWD
cd ${PROJECT_PATH}
## Do the gender report here
if [ ! -f ${PROJECT_PATH}/done/master/${PROJECT}_GenderReport.txt.done ] && [ ${sexchromosomes} == "yes" ]; then
	mkdir -p ${PROJECT_PATH}/done/master
	echo -e "Subject\tReported\tDetermined\tChromosomes\tProcessed\tWarnings" > ${PROJECT_PATH}/${PROJECT}_GenderReport.txt
	for i in $(awk '{ print $1; }' ${samplemap} | sort -n | tr "\n" " "); do
		coverage=$(dirname $(awk '$1 ~ /^'${i}'$/{ print $2; }' ${samplemap}))/*coverage.sh
		if [ ! -f ${coverage} ]; then
			(echo -e "ERROR: Can not find a coverage file for individual ${i} in $(dirname $(dirname ${coverage}))." 1>&2)
			exit 1
		fi
		reported=$(awk '$2 ~ /^'${i}'$/{ print $5; }' ${PED})
		if [ -z ${reported} ]; then
			(echo -e "ERROR: Can not find an entry for individual ${i} in file ${PED} to determine reported gender." 1>&2)
			exit 1
		elif [ "${reported}" -eq 1 ]; then
			reportedgender=Male
		elif [ "${reported}" -eq 2 ]; then
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
# I am using a file to store these values rather than EXPORT because it allows a restart and ensures these values do not have to be re-entered - they should not change for a restart!
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
	if [ $? -ne 0 ] || [ "$genojob" == "" ]; then
		(printf "FAILED!\n" 1>&2)
		exit 1
	else
		echo "Import_${PROJECT} job is ${importjob}"
		(printf "%sx%-4d [%s] Logs @ %s\n" "$importjob" $(splitByChar "$importArray" "," | wc -w) $(condenseList "$importArray") "${PROJECT_PATH}/slurm/GenomeDB/import-${genojob}_*.out" 1>&2)
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

##applyrecal
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

#### Merge the unsplit contig vcf.gz files together  dependent on afterok:${refinejob}
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
### 
#### Mendelian violations report -dependent on merge of unsplit contigs only
mkdir -p ${PROJECT_PATH}/slurm/mendelviol
if [ ! -f "${PROJECT_PATH}/done/mendelviol/${PROJECT}_MendelianViolations.txt.done" ]; then
	mendelvioljob=$(sbatch $(depCheck $mergejob) -J MendelViol_${PROJECT} ${mailme} ${SLSBIN}/mendelviol.sl | awk '{print $4}')
	if [ $? -ne 0 ] || [ "$mergejob" == "" ]; then
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
#if [ "${mergesplitjob}" != "" ] && [ "${mendelvioljob}" != "" ]; then
#	depend="--dependency=afterok:${mergesplitjob}:${mendelvioljob}"
#elif [ "${mergesplitjob}" != "" ]; then
#	depend="--dependency=afterok:${mergesplitjob}"
#elif [ "${mendelvioljob}" != "" ]; then
#	depend="--dependency=afterok:${mendelvioljob}"
#else 
#	depend=""
#fi
if [ ! -f "${PROJECT_PATH}/done/move/directoriesremoved.done" ]; then
	movejob=$(sbatch $(depCheck ${mergesplitjob}:${mendelvioljob}) -J Move_${PROJECT} ${mailme} ${SLSBIN}/move.sl | awk '{print $4}')
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
cleanjob=$(sbatch $(depCheck $movejob) -J Clean_${PROJECT} ${mailme} ${SLSBIN}/clean.sl | awk '{print $4}')
echo "Clean_${PROJECT} job is ${cleanjob}"
