#!/bin/bash
set -x
#. ~/.profile
##
# splitter.bash
#
# Copyright (C) 2019 Synopsys, Inc.
# http://www.synopsys.com/
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
##


# Note: If there are > SIZE_LIMIT files in a single directory this script cannot split it
# and the directory will be skipped
#


#
SYNOPSYS_DETECT_VERSION="${DETECT_LATEST_RELEASE_VERSION}"
BLACKDUCK_URL="https://parallelwireless.app.blackduck.com"
BLACKDUCK_API_TOKEN=$(echo "$bd_token")
BOM_TOOL_SEARCH_DEPTH=11
BOM_TOOL_SEARCH_CONTINUE=true
LOG_LEVEL=DEBUG

#export SCRIPT_LOCATION=`dirname $0`
export SCRIPT_LOCATION="$(pwd)"
export PROJECT_NAME="$1"
export PROJECT_VERSION_NAME="$2"
export CODE_LOCATION_PREFIX="$3"
export BOM_AGGREGATE_NAME="$4"
export TARGET_DIR=${5:-.}
export SIZE_LIMIT=${6:-5.0G}
shift 6
BD_PARAMETERS=( "$@" )

export EXIT_STATUS=0

# List of folders we were not able to scan, e.g. cause they contain too many files
export UNABLE_TO_SCAN=""

function pre-requisites()
{
	if [ "$(which bc)" == "" ]; then
		echo "Requires the bc linux command, please install it"
		exit 1
	fi
}

function metrics()
{
        echo "[INFO] ##### The project scan statistic #####"
        TOTAL_SIZE=`du -sh ${TARGET_DIR} 2>/dev/null | awk '{ print $1}'`
        TOTAL_FILES=`find ${TARGET_DIR} -type f 2>/dev/null | wc -l`
        echo "[INFO] Total Size of the Project - [${TOTAL_SIZE}]"
        echo "[INFO] Total Files in the Project - [${TOTAL_FILES}]"
}

function normalize_size_number()
{
	du_str=$1
	magnitude=$(echo "${du_str: -1}")
	number="${du_str%?}"
	# echo "magnitude: ${magnitude}"
	# echo "initial number: ${number}"

	# need bc to multiply floats
	if [ "${magnitude}" == "M" ]; then
		number=$( echo "$number * 1024" | bc )
	elif [ "${magnitude}" == "G" ]; then
		number=$( echo "$number * 1024 * 1024" | bc )
	fi
	# echo "final number: ${number}"
	echo ${number}
}

function sum_of_subdirs()
{
	sub_dirs=("$@")

	# echo "sub_dirs: ${sub_dirs[@]}"
	sum=0
	for dir in "${sub_dirs[@]}"
	do
		normalized_folder_size=$(normalize_size_number $(du -sh ${dir}) )
		sum=$(echo "${sum} + ${normalized_folder_size}" | bc)
		# echo "normalized_folder_size: $normalized_folder_size"
		# echo "sum: $sum"
	done
	echo $sum
}

function can_we_split()
{
	# Assess whether splitting the scans across the sub-folders will get the
	# size of the scans under the limit; returns 'yes' if we can, 'no' if we cannot
	folder_size=$1
	size_of_subdirs="$2"

	# echo "size_of_subdirs: $size_of_subdirs"
	difference=$(echo "$folder_size - $size_of_subdirs" | bc)
	# echo "difference: $difference"
	comparison=$(echo $difference '<=' $normalized_size_limit | bc )
	if [ "${comparison}" -eq 1 ]; then
		echo "yes"
	else
		echo "no"
	fi
}

function download_SYNOPSYS_DETECT_jar()
{
	echo "[INFO] Downloading the synopsys-detect.jar version [${SYNOPSYS_DETECT_VERSION}] from Black Duck Artifactory"
	curl -o  ${SCRIPT_LOCATION}/synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar \
		 "https://sig-repo.synopsys.com/bds-integrations-release/com/synopsys/integration/synopsys-detect/${SYNOPSYS_DETECT_VERSION}/synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar"

	export SYNOPSYS_DETECT_JAR_LOCATION="${SCRIPT_LOCATION}/synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar"
	export DETECT_JAR_PATH="${SCRIPT_LOCATION}"
	export DETECT_SOURCE="https://sig-repo.synopsys.com/bds-integrations-release/com/synopsys/integration/synopsys-detect/${SYNOPSYS_DETECT_VERSION}/synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar" 
	export DETECT_FILENAME="synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar"
}

function scan()
{       
	scan_number=${#FOLDERS_TO_SCAN[@]}
	#BOM Scan + 1
	scan_number=$(($scan_number+1))
	scan_counter=0
	echo "[INFO] Starting project scanning..."
	echo "[INFO] Total number of scans are [${scan_number}]"

        if [[ ${#FOLDERS_TO_SCAN[@]} -eq 1 ]]; then
        	#detect_log="${LOG_DIR}/detect.log"
            	echo "[INFO] Running synopsys-detect BOM & Signature Scan in: ${FOLDERS_TO_SCAN[0]}"
		CODE_LOCATION_NAME=$CODE_LOCATION_PREFIX"_split_"$scan_number
		DETECT_PARAMS="--logging.level.com.synopsys.integration=$LOG_LEVEL --detect.source.path=${FOLDERS_TO_SCAN[0]} --detect.code.location.name=${CODE_LOCATION_NAME} --detect.bom.aggregate.name=${BOM_AGGREGATE_NAME} --detect.detector.search.depth=$BOM_TOOL_SEARCH_DEPTH --detect.detector.search.continue=$BOM_TOOL_SEARCH_CONTINUE --detect.project.name=${PROJECT_NAME} --detect.project.version.name=${PROJECT_VERSION_NAME} --detect.timeout=6000 --detect.conan.path=/usr/local/bin/conan --detect.excluded.detector.types=CPAN --detect.nuget.inspector.air.gap.path=/opt/packaged-inspectors/nuget/ --detect.dotnet.path=/usr/local/bin/dotnet --detect.gradle.inspector.air.gap.path=/opt/packaged-inspector/gradle/"
		echo "[INFO] Running [java -jar ${SCRIPT_LOCATION}/synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar --blackduck.url=$BLACKDUCK_URL --blackduck.api.token=$BLACKDUCK_API_TOKEN --blackduck.trust.cert=true ${DETECT_PARAMS}]"
		#nohup java -jar ${SCRIPT_LOCATION}/synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar "${BD_PARAMETERS[@]}" ${DETECT_PARAMS} > ${LOG_DIR}/${detect_log} 2>&1 &
		echo "----------RUNNING DETECT BOM and SIGNATURE SCAN--------------"
		java -jar ${SCRIPT_LOCATION}/synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar --blackduck.url=$BLACKDUCK_URL --blackduck.api.token=$BLACKDUCK_API_TOKEN --blackduck.trust.cert=true ${DETECT_PARAMS}

        else
		scan_counter=$(($scan_counter+1))
		#detect_log="${LOG_DIR}/detect_bom.log"
		echo "[INFO] Running synopsys-detect BOM Scan in: ${TARGET_DIR}"
		CODE_LOCATION_NAME=$CODE_LOCATION_PREFIX"_split_"$scan_number"_"$scan_counter
		DETECT_PARAMS="--logging.level.com.synopsys.integration=$LOG_LEVEL --detect.source.path=${TARGET_DIR} --detect.code.location.name=${CODE_LOCATION_NAME} --detect.tools=DETECTOR --detect.bom.aggregate.name=${BOM_AGGREGATE_NAME} --detect.detector.search.depth=$BOM_TOOL_SEARCH_DEPTH --detect.detector.search.continue=$BOM_TOOL_SEARCH_CONTINUE --detect.project.name=${PROJECT_NAME} --detect.project.version.name=${PROJECT_VERSION_NAME} --detect.timeout=6000 --detect.conan.path=/usr/local/bin/conan --detect.excluded.detector.types=CPAN --detect.nuget.inspector.air.gap.path=/opt/packaged-inspectors/nuget/ --detect.gradle.inspector.air.gap.path=/opt/packaged-inspector/gradle/ --detect.dotnet.path=/usr/local/bin/dotnet"
            	echo "[INFO] Running [java -jar ${SCRIPT_LOCATION}/synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar --blackduck.url=$BLACKDUCK_URL --blackduck.api.token=$BLACKDUCK_API_TOKEN --blackduck.trust.cert=true ${DETECT_PARAMS}]"
		#nohup java -jar ${SCRIPT_LOCATION}/synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar "${BD_PARAMETERS[@]}" ${DETECT_PARAMS} > ${LOG_DIR}/${detect_log} 2>&1 &
		echo "----------RUNNING DETECT BOM SCAN--------------"
		java -jar ${SCRIPT_LOCATION}/synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar --blackduck.url=$BLACKDUCK_URL --blackduck.api.token=$BLACKDUCK_API_TOKEN --blackduck.trust.cert=true ${DETECT_PARAMS}

		for scan_dir in ${FOLDERS_TO_SCAN[@]}
			do
				scan_counter=$(($scan_counter+1))
			    	#detect_log="${LOG_DIR}/detect_"$scan_counter".log"
        	    	    	echo "[INFO] Running synopsys-detect Signature Scan in: ${scan_dir}"
			    	CODE_LOCATION_NAME=$CODE_LOCATION_PREFIX"_split_"$scan_number"_"$scan_counter
			    	DETECT_PARAMS="--logging.level.com.synopsys.integration=$LOG_LEVEL --detect.source.path=${scan_dir} --detect.code.location.name=${CODE_LOCATION_NAME} --detect.project.name=${PROJECT_NAME} --detect.project.version.name=${PROJECT_VERSION_NAME} --detect.timeout=6000 --detect.conan.path=/usr/local/bin/conan --detect.excluded.detector.types=CPAN --detect.nuget.inspector.air.gap.path=/opt/packaged-inspectors/nuget/ --detect.gradle.inspector.air.gap.path=/opt/packaged-inspector/gradle/ --detect.dotnet.path=/usr/local/bin/dotnet"
		    	    	echo "[INFO] Running [java -jar ${SCRIPT_LOCATION}/synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar --blackduck.url=$BLACKDUCK_URL --blackduck.api.token=$BLACKDUCK_API_TOKEN --blackduck.trust.cert=true ${DETECT_PARAMS}]"
        	    		#nohup java -jar ${SCRIPT_LOCATION}/synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar "${BD_PARAMETERS[@]}" ${DETECT_PARAMS} > ${LOG_DIR}/${detect_log} 2>&1 &
			    	echo "----------RUNNING DETECT SIGNATURE SCAN--------------"
			    	java -jar ${SCRIPT_LOCATION}/synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar --blackduck.url=$BLACKDUCK_URL --blackduck.api.token=$BLACKDUCK_API_TOKEN --blackduck.trust.cert=true ${DETECT_PARAMS}
			done
        fi
    #echo "Scanning only files under Parent Directory [${TARGET_DIR}]"
    #CODE_LOCATION_NAME=$CODE_LOCATION_PREFIX"_split_topdirfiles"
    #DETECT_PARAMS="--logging.level.com.synopsys.integration=$LOG_LEVEL --detect.source.path=${TARGET_DIR} --detect.blackduck.signature.scanner.paths=$(find "$TARGET_DIR" -maxdepth 1 -type f | paste -s -d ',' -) --detect.code.location.name=${CODE_LOCATION_NAME} --detect.project.name=${PROJECT_NAME} --detect.project.version.name=${PROJECT_VERSION_NAME}"
  	#java -jar ${SCRIPT_LOCATION}/synopsys-detect-${SYNOPSYS_DETECT_VERSION}.jar --blackduck.url=$BLACKDUCK_URL --blackduck.api.token=$BLACKDUCK_API_TOKEN --blackduck.trust.cert=true ${DETECT_PARAMS}

}

function scan_when_under_limit()
{
	du_str=$(du -sh . | awk '{print $1}')
	#echo "du_str for $(basename $(pwd)): $du_str"
	normalized_folder_size=$(normalize_size_number $du_str) 
	normalized_size_limit=$(normalize_size_number "${SIZE_LIMIT}")
	#need bc to compare floats
	bc_comparison=$(echo $normalized_folder_size '<=' $normalized_size_limit | bc -l)
	if [ "${bc_comparison}" -eq 1 ]; then
		echo "Under, or equal to, the limit, scanning..."
		#scan
		FOLDERS_TO_SCAN+=($(pwd))
	else
		echo "[INFO] Over the limit, trying to sub-divide by scanning the sub-folders"
		dirs=($(find . -maxdepth 1 -type d | grep "/"))
		# echo "dirs: ${dirs[@]}"
		subdir_sum=$(sum_of_subdirs ${dirs[@]})
		# echo "du sum of subdirs: ${subdir_sum}"
		answer=$(can_we_split ${normalized_folder_size} ${subdir_sum})
		# echo "answer: $answer"
		if [ "${answer}" == "yes" ]; then
			echo "[INFO] Splitting $(pwd) by scanning its subdirs"
			for dir in ${dirs[@]}
			do
				cd $dir
				scan_when_under_limit
				cd ..
			done
		else
			echo "Cannot split $(pwd)"
			UNABLE_TO_SCAN="${UNABLE_TO_SCAN} $(pwd)"
		fi
	fi
}

# # # #   M A I N   # # # #

# FIXME: set for now the skip, need to check how to fix the exception via scan
export BLACKDUCK_SKIP_PHONE_HOME=true
#export SCAN_CLI_OPTS="-Dspring.profiles.active=bds-disable-scan-graph"

#((!$#)) && echo No arguments supplied! && exit 1

if [ $# -lt 5 ]
then
	echo "[ERROR]  Please INPUT all required arguments"
  	echo "Usage : ./enhanced-splitter.sh <PROJECT_NAME> <PROJECT_VERSION_NAME> <CODE_LOCATION_PREFIX> <BOM_AGGREGATE_NAME> <TARGET_DIR>"
  	exit 1
fi

pre-requisites
metrics
download_SYNOPSYS_DETECT_jar
cd ${TARGET_DIR}
echo "Start: $(date)"
scan_when_under_limit
if [ "${UNABLE_TO_SCAN}" != "" ]; then
	echo "[ERROR] Unable to split folder"
	echo "${UNABLE_TO_SCAN}" | xargs -n1
	exit 1
fi
scan
echo "Done: $(date)"

exit ${EXIT_STATUS}
