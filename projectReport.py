import requests
import json
import sys
import os
import time
import zipfile


url = "https://parallelwireless.app.blackduck.com/api/tokens/authenticate"

headers = {
  'Authorization': 'token OGUwYTBjOTYtY2E0MC00YmJhLTkwMTEtMDMxY2QwMDA3ZDQ2OmU2M2E1MzA2LTM3MDMtNGJhZi1hOTk5LTc1ZTViMjZjMDNmZg=='
}

response = requests.request("POST", url, headers=headers)

bearertoken = response.json()['bearerToken']
#print(bearertoken)

xcsrftoken = response.headers['X-CSRF-TOKEN']
#print(xcsrftoken)


projectName=sys.argv[1]
versionName=sys.argv[2]
commitID=sys.argv[3]
if projectName == "":
        exit("Please specify the package name")



projectURLs = "https://parallelwireless.app.blackduck.com/api/projects?limit=100"

projectheaders = {
  'X-CSRF-TOKEN': xcsrftoken,
  'Content-Type': 'application/vnd.blackducksoftware.component-detail-4+json',
  'Authorization': 'Bearer '+bearertoken
}


projectresponse = requests.request("GET", projectURLs, headers=projectheaders)

projectdata = projectresponse.json()
ReportURL = ""

for each in projectdata['items']:
        if each['name'] == projectName:
                print(each['_meta']['links'][0]['href'])
                versionsresponse = requests.request("GET", each['_meta']['links'][0]['href'], headers=projectheaders)
                versionsdata = versionsresponse.json()
                for eachversion in versionsdata['items']:

                        if eachversion['versionName'] == versionName:
                                ReportURL = eachversion['_meta']['links'][8]['href']
                                with open('securityRiskProfile.json', 'w') as f:
                                        json.dump(eachversion['securityRiskProfile'], f)
                                with open('licenseRiskProfile.json', 'w') as f:
                                       json.dump(eachversion['licenseRiskProfile'], f)
                                with open('operationalRiskProfile.json', 'w') as f:
                                        json.dump(eachversion['operationalRiskProfile'], f)

#print(ReportURL)
versionid = ReportURL.split('/')[7]
ReportURL = "https://parallelwireless.app.blackduck.com/api/versions/"+versionid+"/reports"
#print(ReportURL)
reportheaders = {
        'X-CSRF-TOKEN': xcsrftoken,
        'Content-Type': 'application/vnd.blackducksoftware.report-4+json',
        'Authorization': 'Bearer '+bearertoken
}
reportdata = "{ \"reportFormat\" : \"CSV\", \"locale\" : \"en_US\", \"versionId\" : \""+versionid+"\", \"categories\": [\"COMPONENTS\"], \"reportType\" : \"[VERSION_LICENSE, VERSION, VERSION_VULNERABILITY_REMEDIATION, VERSION_VULNERABILITY_STATUS, VERSION_VULNERABILITY_UPDATE]\" }\r\n"


reportresponse = requests.request("POST", ReportURL, headers=reportheaders, data=reportdata)

time.sleep(120)

reportlistreponse = requests.request("GET", ReportURL+"?limit=1", headers=reportheaders)

reportlistdata = reportlistreponse.json()

#print(reportlistdata)
csvtimestamp=""
for reporteachlist in reportlistdata['items']:
        reportStatus = reporteachlist['status']
        counter = 0
        while reportStatus == "IN_PROGRESS":
                time.sleep(60)
                counter = counter+1
                reportlistreponse = requests.request("GET", ReportURL+"?limit=1", headers=reportheaders)
                reportlistdataforloop = reportlistreponse.json()
                reportStatus = reportlistdataforloop['items'][0]['status']
                if counter == 10:
                        raise ValueError('Report Generation taking long time. Please check on blackduck site : https://parallelwireless.app.blackduck.com/')
        downloadURL=reporteachlist['_meta']['links'][1]['href']
        r = requests.request("GET", downloadURL, headers=reportheaders)
        with open(projectName+"_"+versionName+".zip", "wb") as code:
                code.write(r.content)
        with zipfile.ZipFile(projectName+"_"+versionName+".zip", 'r') as zip_ref:
                filename = zip_ref.extractall()
        os.system("mv "+projectName+"-"+versionName+"* "+projectName+"-"+versionName)
        os.remove(projectName+"_"+versionName+".zip")
        csvfilename = os.listdir(projectName+"-"+versionName)[0].split(".")[0].split("_")
        csvtimestamp = csvfilename[1]+"_"+csvfilename[2]
        os.system("mv "+projectName+"-"+versionName+"/*.csv "+projectName+"-"+versionName+"/"+projectName+"-"+versionName+"-"+commitID+"-"+csvtimestamp+".csv")
        os.system("mv securityRiskProfile.json securityRiskProfile_"+csvtimestamp+".json")
        os.system("mv licenseRiskProfile.json licenseRiskProfile_"+csvtimestamp+".json")
        os.system("mv operationalRiskProfile.json operationalRiskProfile_"+csvtimestamp+".json")