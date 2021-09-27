#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "#############################################################################"
    echo "#                    Illegal number of parameters                           #"
    echo "#            ./blackduckProjectReport.sh <projectName> <versionName>        #"
    echo "#      Ex : ./blackduckProjectReport.sh 2g-stack develop-HEAD               #"
    echo "#############################################################################"
else

curl -v --location --request POST 'https://parallelwireless.app.blackduck.com/api/tokens/authenticate' --header 'Authorization: token OGUwYTBjOTYtY2E0MC00YmJhLTkwMTEtMDMxY2QwMDA3ZDQ2OmU2M2E1MzA2LTM3MDMtNGJhZi1hOTk5LTc1ZTViMjZjMDNmZg==' > out.txt 2>&1

crpfToken=$(cat out.txt | grep "x-csrf-token" | cut -d ":" -f2 | sed 's/[ ]//g')
bearerToken=$(cat out.txt | grep "bearerToken" | cut -d ":" -f2 | cut -d "," -f1 | sed 's/["]//g')

if [ "$crpfToken" == "" ]
then
	echo "No X-CRPF TOKEN found"
	exit 1
fi
if [ "$bearerToken" == "" ]
then
        echo "No Bearer TOKEN found"
        exit 1
fi
#echo "CRPF TOKEN : $crpfToken"
#echo ""
#echo ""
#echo ""
#echo "Bearer Token : $bearerToken"


rm -rf out.txt

projectName="$1"
versionName="$2"

#versionID=$(curl -k -X GET -H "Accept: application/vnd.blackducksoftware.project-detail-4+json" -H "Authorization: bearer ${bearerToken}" https://parallelwireless.app.blackduck.com/api/projects?limit=100 | jq '.items' | jq '.[] | select(.name=="'$projectName'") | ._meta.links | .[] | .href' | grep -o -P '(?<=versions/).*(?=\")')

projectIDUrl=$(curl -k -X GET -H "Accept: application/vnd.blackducksoftware.project-detail-4+json" -H "Authorization: bearer ${bearerToken}" https://parallelwireless.app.blackduck.com/api/projects?limit=100 | jq '.items' | jq '.[] | select(.name=="'$projectName'") | ._meta.href' | sed 's/["]//g')

if [ "$projectIDUrl" == "" ]
then
        echo "No Project ID URL found"
        exit 1
fi

versionID=$(curl -k -X GET -H "Accept: application/vnd.blackducksoftware.project-detail-5+json" -H "Authorization: bearer ${bearerToken}" "$projectIDUrl/versions" | jq '.items | .[] | select(.versionName=="'$versionName'") | ._meta.links | .[] | .href' |  tail -2 | head -1 | grep -o -P '(?<=versions/).*(?=\")')

if [ "$versionID" == "" ]
then
        echo "No version ID URL found"
        exit 1
fi

#echo "Version ID : $versionID"

projectID=$(echo "$projectIDUrl" | rev | cut -d "/" -f 1 | rev)

if [ "$projectID" == "" ]
then
        echo "No Project ID found"
        exit 1
fi

curl --http1.1 --location --request POST "https://parallelwireless.app.blackduck.com/api/versions/$versionID/reports" \
--header "X-CSRF-TOKEN: ${crpfToken}" \
--header 'Content-Type: application/vnd.blackducksoftware.report-4+json' \
--header "Authorization: bearer ${bearerToken}" \
--data-raw '{ "reportFormat" : "CSV", "locale" : "en_US", "versionId" : "'"$versionID"'", "categories" : ["COMPONENTS"], "reportType" : "[VERSION_LICENSE, VERSION, VERSION_VULNERABILITY_REMEDIATION, VERSION_VULNERABILITY_STATUS, VERSION_VULNERABILITY_UPDATE]" }'


downloadUrl=$(curl -k -X GET "https://parallelwireless.app.blackduck.com/api/versions/$versionID/reports?limit=1" \
--header "Authorization: bearer ${bearerToken}" --header "Accept: application/vnd.blackducksoftware.report-4+json" | jq '.items | .[] | ._meta.links | .[] | .href' | tail -1 | sed 's/["]//g')

#echo "$downloadUrl"
echo "Generating CSV report for $projectName - $releaseName"
sleep 300
curl -k -X GET "$downloadUrl" --header "Authorization: bearer ${bearerToken}" --header "Accept: application/vnd.blackducksoftware.report-4+json" --output $projectName.$versionName.zip

COMMITID=$(git rev-parse HEAD)
REPORTDATE=$(date '+%Y%m%d%H%M')

if [ -f "$projectName.$versionName.zip" ]; then
    unzip $projectName.$versionName.zip
    rm -rf $projectName.$versionName.zip
    mv $projectName*/ "${REPOSITORY_NAME}-{PW_BRANCH}-$COMMITID-$REPORTDATE"/
    mv "${REPOSITORY_NAME}-{PW_BRANCH}-$COMMITID-$REPORTDATE"/ /work/sa.pw-bldmgr/blackduck_csv_reports/
    mv /work/sa.pw-bldmgr/blackduck_csv_reports/"${REPOSITORY_NAME}-{PW_BRANCH}-$COMMITID-$REPORTDATE"/*.csv /work/sa.pw-bldmgr/blackduck_csv_reports/"${REPOSITORY_NAME}-{PW_BRANCH}-$COMMITID-$REPORTDATE"/"${REPOSITORY_NAME}-${PW_BRANCH}".csv 
else
   echo "please check the rest api urls properly"   
fi

fi
