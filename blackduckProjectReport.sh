#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "#######################################################################################"
    echo "#                    Illegal number of parameters                                     #"
    echo "#            ./blackduckProjectReport.sh <projectName> <versionName>  <commitid>      #"
    echo "#      Ex : ./blackduckProjectReport.sh 2g-stack develop-HEAD 6adsfa7                 #"
    echo "#######################################################################################"
else

curl -v --location --request POST 'https://parallelwireless.app.blackduck.com/api/tokens/authenticate' --header 'Authorization: token OGUwYTBjOTYtY2E0MC00YmJhLTkwMTEtMDMxY2QwMDA3ZDQ2OmU2M2E1MzA2LTM3MDMtNGJhZi1hOTk5LTc1ZTViMjZjMDNmZg==' > out.txt 2>&1

crpfToken=$(cat out.txt | grep "X-CSRF-TOKEN:" | cut -d ":" -f2 | sed 's/[ ]//g')
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
PW_BRANCH=""
if [ "$versionName" == "release-6.2" ]
then
	PW_BRANCH="release/REL_6.2.x"
else
	PW_BRANCH=$(echo "$versionName" | cut -d "-" -f1)
fi

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

curl  --location --request POST "https://parallelwireless.app.blackduck.com/api/versions/$versionID/reports" \
--header "X-CSRF-TOKEN: ${crpfToken}" \
--header 'Content-Type: application/vnd.blackducksoftware.report-4+json' \
--header "Authorization: bearer ${bearerToken}" \
--data '{ "reportFormat" : "CSV", "locale" : "en_US", "versionId" : "'"$versionID"'", "categories" : ["COMPONENTS"], "reportType" : "[VERSION_LICENSE, VERSION, VERSION_VULNERABILITY_REMEDIATION, VERSION_VULNERABILITY_STATUS, VERSION_VULNERABILITY_UPDATE]" }'


downloadUrl=$(curl -k -X GET "https://parallelwireless.app.blackduck.com/api/versions/$versionID/reports?limit=1" \
--header "Authorization: bearer ${bearerToken}" --header "Accept: application/vnd.blackducksoftware.report-4+json" | jq '.items | .[] | ._meta.links | .[] | .href' | tail -1 | sed 's/["]//g')

echo "$downloadUrl"
echo "Generating CSV report for $projectName - $versionName"
sleep 300

curl -k -X GET "$downloadUrl" --header "Authorization: bearer ${bearerToken}" --header "Accept: application/vnd.blackducksoftware.report-4+json" --output $projectName.$versionName.zip

COMMITID=$3
#REPORTDATE=$(date '+%Y-%m-%d.%H:%M')


if [ -f "$projectName.$versionName.zip" ]; then
    unzip $projectName.$versionName.zip
    rm -rf $projectName.$versionName.zip
    mv $projectName-$versionName*/ "$projectName"/
    REPORTDATE=$(ls "$projectName" | cut -d "_" -f2,3 | cut -d '.' -f1)
    
    if [ -d "/work/sa.pw-bldmgr/blackduck_csv_reports/develop/$projectName/" ]
    then
    	mv "$projectName"/*.csv /work/sa.pw-bldmgr/blackduck_csv_reports/develop/"$projectName"/
    else
	mkdir -p /work/sa.pw-bldmgr/blackduck_csv_reports/develop/"$projectName"/
        mv "$projectName"/*.csv /work/sa.pw-bldmgr/blackduck_csv_reports/develop/"$projectName"/
    fi
    mv /work/sa.pw-bldmgr/blackduck_csv_reports/develop/"$projectName"/components*.csv /work/sa.pw-bldmgr/blackduck_csv_reports/develop/"$projectName"/"$projectName-$PW_BRANCH-$COMMITID-$REPORTDATE".csv

    echo "Copying Generated CSV file to DEVOPS DASHBOARD WEBSITE"
    scp -r /work/sa.pw-bldmgr/blackduck_csv_reports/develop/"$projectName"/"$projectName-$PW_BRANCH-$COMMITID-$REPORTDATE".csv parallel@10.136.2.223:/blackduckreports/develop/"$projectName"/
else
   echo "please check the rest api urls properly"   
fi

fi
