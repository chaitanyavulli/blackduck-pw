import requests
import json
import sys
import os
import math

url = "https://parallelwireless.app.blackduck.com/api/tokens/authenticate"

headers = {
  'Authorization': 'token OGUwYTBjOTYtY2E0MC00YmJhLTkwMTEtMDMxY2QwMDA3ZDQ2OmU2M2E1MzA2LTM3MDMtNGJhZi1hOTk5LTc1ZTViMjZjMDNmZg=='
}

response = requests.request("POST", url, headers=headers)

bearertoken = response.json()['bearerToken']
#print(bearertoken)

xcsrftoken = response.headers['X-CSRF-TOKEN']
#print(xcsrftoken)


packageName=sys.argv[1]

if packageName == "":
	exit("Please specify the package name")

knowledgebaseURL = "https://parallelwireless.app.blackduck.com/api/search/kb-components?limit=500&q="+packageName

knowledgebaseheaders = {
  'X-CSRF-TOKEN': xcsrftoken,
  'Content-Type': 'application/vnd.blackducksoftware.component-detail-4+json',
  'Authorization': 'Bearer '+bearertoken
}


knowledgebaseresponse = requests.request("GET", knowledgebaseURL, headers=knowledgebaseheaders)

knowledgebasedata = knowledgebaseresponse.json()
componentURL = ""
releaseCountList = []
for each in knowledgebasedata['items']:
	for eachhit in each['hits']:
		if str(eachhit['fields']['name'][0]) == str(packageName):
			releaseCountList = releaseCountList + eachhit['fields']['release_count']

releaseCountList = list(map(int, releaseCountList))
largestReleaseCount = max(releaseCountList)
componentuuid = ""
for each in knowledgebasedata['items']:
	for eachhit in each['hits']:
		if int(str(eachhit['fields']['release_count'][0])) == largestReleaseCount and str(eachhit['fields']['name'][0]) == str(packageName):
			componentuuid = str(eachhit['fields']['uuid'][0])


#print(componentuuid)
versionNumber=sys.argv[2]
if versionNumber == "":
	exit("Please specify correct version number of the package")

componentURL = "https://parallelwireless.app.blackduck.com/api/components/"+componentuuid
componentVersionsurl = componentURL+"/versions?limit=100&offset=0&q=versionName:"+versionNumber
componentVersionresponse = requests.request("GET", componentVersionsurl, headers=knowledgebaseheaders)
#print(componentVersionresponse.json()['items'][0]['_meta']['links'][4]['href'])
vulnerabilitiesurl = componentVersionresponse.json()['items'][0]['_meta']['links'][4]['href']

vulnerabilitiesreponse = requests.request('GET', vulnerabilitiesurl, headers=knowledgebaseheaders)

vulnerabilitiesdata = vulnerabilitiesreponse.json()

#print(vulnerabilitiesdata['totalCount'])

if vulnerabilitiesdata['totalCount'] == 0:
	with open('vulnerabilitiesCount', "w") as vulCount:
		vulCount.write(str(vulnerabilitiesdata['totalCount']))

else:
	for eachvul in vulnerabilitiesdata['items']:
		with open("vulnerabilities.txt", "a") as myfile:
			myfile.write("Vulnerability Name: "+eachvul['vulnerabilityName']+"\n")
			myfile.write("Description: "+eachvul['description']+"\n")
			myfile.write("Source: "+eachvul['source']+"\n")
			myfile.write("Severity: "+eachvul['severity']+"\n")
			myfile.write("CWE ID: "+eachvul['cweId']+"\n")
			myfile.write("********************************************************************************************************\n")


for licenseURL in componentVersionresponse.json()['items'][0]['license']['licenses']:
	with open("licensedetails.txt", "a") as licensefile:
		licensefile.write(licenseURL['name']+"\n")
		licenseDetailURL = licenseURL['license']+"/text"
		licenseDetailresponse = requests.request("GET", licenseDetailURL, headers=knowledgebaseheaders)
		licensefile.write(licenseDetailresponse.json()['text']+"\n")
		licensefile.write("********************************************************************************************************\n")
