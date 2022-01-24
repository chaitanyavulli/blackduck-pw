#!/user/bin/env groovy
import org.jenkinsci.plugins.pipeline.modeldefinition.Utils
node('blackduck-scan')
{
timestamps{
	properties([
		parameters([
			string(defaultValue: 'network', description: 'Defining parameter for repository name', name: 'REPOSITORY_NAME', trim: false),
			string(defaultValue: 'develop', description: 'Defining parameter for branch name', name: 'PW_BRANCH', trim: false),
			string(defaultValue: '7.8.0', description: 'DETECT CLI VERSION', name: 'DETECT_VERSION', trim: false)
		])
	])
	def BDToken="MTdiOWNkYTQtZDA2Yy00YzBhLTk0MzctMDMxMzU4MGQ0YWY1OjU3ODZjOGM4LTVkMDYtNDA0ZS1iNWNhLTVlMDYzZTg4ZTVhNw=="
	def verCode = UUID.randomUUID().toString()
	def COMMITID
	def bd_project_name
	def projectSourcePath
	def bd_version_name
	
	if ("${PW_BRANCH}" == "develop")
	{
		bd_version_name = "develop-HEAD"
	}
	else if ("${PW_BRANCH}".contains("release"))
	{
		def releaseBranchSplit = "${PW_BRANCH}".tokenize( '/' )
		bd_version_name = "${releaseBranchSplit[1]}"
	}
	else{
		bd_version_name = "${PW_BRANCH}"
	}
	
	currentBuild.displayName = "#${BUILD_NUMBER}, ${REPOSITORY_NAME}"
	currentBuild.description = "#${BUILD_NUMBER}, ${PW_BRANCH}"
	
	dir("${verCode}")
	{
		try{
			if ("${REPOSITORY_NAME}" == "network")
			{
				projectSourcePath = "${WORKSPACE}/${verCode}/${REPOSITORY_NAME}/hng"
			}
			else if ("${REPOSITORY_NAME}" == "core")
			{
				projectSourcePath = "${WORKSPACE}/${verCode}/${REPOSITORY_NAME}/vru"
			}
			else if ("${REPOSITORY_NAME}" == "core-stacks")
			{
				projectSourcePath = "${WORKSPACE}/${verCode}/${REPOSITORY_NAME}/ltestack"
			}
			else
			{
				projectSourcePath = "${WORKSPACE}/${verCode}/${REPOSITORY_NAME}/"
			}
			
			if ("${REPOSITORY_NAME}" == "rt-monitoring")
			{
				bd_project_name="IOND-rt-monitoring"
			}
			else
			{
				bd_project_name="${REPOSITORY_NAME}"
			}
			
			stage('Fetch Product Repository'){
				//checkout([$class: 'GitSCM', branches: [[name: '*/${PW_BRANCH}']], extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: '${REPOSITORY_NAME}'], [$class: 'GitLFSPull'], [$class: 'ScmName', name: '${REPOSITORY_NAME}']], userRemoteConfigs: [[credentialsId: 'e8ff24f6-10d1-4129-8c70-7c66d7c2d6d7', url: 'ssh://git@git.parallelwireless.net:7999/cd/${REPOSITORY_NAME}.git']]])
				if ("${REPOSITORY_NAME}" == "rt-monitoring")
				{
					checkout([$class: 'GitSCM', branches: [[name: '*/${PW_BRANCH}']], extensions: [[$class: 'ScmName', name: '${REPOSITORY_NAME}'], [$class: 'RelativeTargetDirectory', relativeTargetDir: '${REPOSITORY_NAME}'], [$class: 'GitLFSPull'], [$class: 'LocalBranch', localBranch: '${PW_BRANCH}']], userRemoteConfigs: [[credentialsId: 'vaultpwbldmgr', url: 'https://nhbbm.parallelwireless.net/scm/git/da/${REPOSITORY_NAME}.git']]])
				}
                else if("${REPOSITORY_NAME}" == "near_rtric")
				{
					checkout([$class: 'GitSCM', branches: [[name: '*/${PW_BRANCH}']], extensions: [[$class: 'ScmName', name: '${REPOSITORY_NAME}'], [$class: 'RelativeTargetDirectory', relativeTargetDir: '${REPOSITORY_NAME}'], [$class: 'GitLFSPull'], [$class: 'LocalBranch', localBranch: '${PW_BRANCH}']], userRemoteConfigs: [[credentialsId: 'vaultpwbldmgr', url: 'https://nhbbm.parallelwireless.net/scm/git/near/${REPOSITORY_NAME}.git']]])
				}
				else{
					checkout([$class: 'GitSCM', branches: [[name: '*/${PW_BRANCH}']], extensions: [[$class: 'ScmName', name: '${REPOSITORY_NAME}'], [$class: 'RelativeTargetDirectory', relativeTargetDir: '${REPOSITORY_NAME}'], [$class: 'GitLFSPull'], [$class: 'LocalBranch', localBranch: '${PW_BRANCH}']], userRemoteConfigs: [[credentialsId: 'vaultpwbldmgr', url: 'https://nhbbm.parallelwireless.net/scm/git/cd/${REPOSITORY_NAME}.git']]])
				}
			}
			
			stage('Build Product'){
				REPONAME = "${REPOSITORY_NAME}".replaceAll("-","");
				if ("$REPONAME" == "2gstack")
				{
					REPONAME="twogstack"
				}
				"$REPONAME"()
			}
			
			
			dir("${REPOSITORY_NAME}"){
				COMMITID = sh(script:"git rev-parse HEAD", returnStdout: true).trim()
				sh """
					rm -rf .git/
				"""
			}
			
			//sizeWorkspace = "${WORKSPACE}/${verCode}/${REPOSITORY_NAME}".size()
			sizeWorkspace = sh(script:"du -sk \${REPOSITORY_NAME}/ | awk '{print \$1}'", returnStdout: true).toInteger()
			echo "Workspace Size = ${sizeWorkspace}"
			
			if ("${sizeWorkspace}".toInteger() > 5242880)
			{
				stage('Blackduck Analysis'){
					dir("${REPOSITORY_NAME}"){
						sh """
							export DETECT_LATEST_RELEASE_VERSION="${DETECT_VERSION}"
							find . -empty -type d -delete
							export bd_token="${BDToken}"
							/opt/bd_tools/enhanced-splitter.sh "${bd_project_name}" ${bd_version_name} "${bd_project_name}-${bd_version_name}" "${bd_project_name}" "$projectSourcePath"
						"""
					}
				}
			}
			else
			{
				stage('Blackduck Analysis'){
					dir("${REPOSITORY_NAME}"){
						sh """
							export DETECT_LATEST_RELEASE_VERSION="${DETECT_VERSION}"
							/opt/bd_tools/detect.sh --blackduck.url=https://parallelwireless.app.blackduck.com --blackduck.api.token="${BDToken}" --detect.project.name="${bd_project_name}" --detect.source.path="$projectSourcePath" --detect.code-location.name="${bd_project_name}-${bd_version_name}" --detect.project.version.name="${bd_version_name}" --detect.project.version.update=true --detect.timeout=6000 --detect.blackduck.signature.scanner.snippet.matching=SNIPPET_MATCHING --detect.conan.path=/usr/local/bin/conan --detect.excluded.detector.types=CPAN --detect.nuget.inspector.air.gap.path=/opt/packaged-inspectors/nuget/ --detect.gradle.inspector.air.gap.path=/opt/packaged-inspector/gradle/ --detect.dotnet.path=/usr/local/bin/dotnet
						"""
					}
				}
			}
			error_check()
			stage('Generating Report'){
				dir("${REPOSITORY_NAME}"){
					if ("${PW_BRANCH}".contains("release"))
					{
						def exists = fileExists "/work/sa.pw-bldmgr/blackduck_csv_reports/${PW_BRANCH}/${REPOSITORY_NAME}/"
						if (!exists)
						{
							sh """
								mkdir -p /work/sa.pw-bldmgr/blackduck_csv_reports/"${PW_BRANCH}"/"${REPOSITORY_NAME}"/
							"""
						}
						sh """
							python3 /work/sa.pw-bldmgr/blackduck_csv_reports/projectReport.py "${bd_project_name}" "${bd_version_name}" "${COMMITID}"
							cp licenseRiskProfile*.json securityRiskProfile*.json operationalRiskProfile*.json "${bd_project_name}"-"${bd_version_name}"/*.csv /work/sa.pw-bldmgr/blackduck_csv_reports/"${PW_BRANCH}"/"${REPOSITORY_NAME}"/
							ssh -o StrictHostKeyChecking=no parallel@10.136.2.223 '[ -d /blackduckreports/"${PW_BRANCH}"/"${REPOSITORY_NAME}"/ ] && echo exists || mkdir -p /blackduckreports/"${PW_BRANCH}"/"${REPOSITORY_NAME}"/'
							scp -o StrictHostKeyChecking=no licenseRiskProfile*.json securityRiskProfile*.json operationalRiskProfile*.json "${bd_project_name}"-"${bd_version_name}"/*.csv parallel@10.136.2.223:/blackduckreports/"${PW_BRANCH}"/"${REPOSITORY_NAME}"/
						"""
					}
					else{
						echo "Report generation not supported for this branch"
					}
                }
				sh '''
						
text="
Hi
						
Blackduck analysis for ${REPOSITORY_NAME} completed. Please find the attachment to view the result

Repository : '${bd_project_name}'
Version : '${bd_version_name}'
						
CSV Report generated and saved on nhcoverity and website servers

Build URL : ${BUILD_URL}

Thanks
"
						echo "$text" > mailBody.txt
						
						cat mailBody.txt | mail -s "${BUILD_DISPLAY_NAME}- BLACKDUCK - ${BUILD_NUMBER}" -r 'buildmgr@parallelwireless.com' releng@parallelwireless.com
				'''
			}
            currentBuild.result = 'SUCCESS'
        } //closing try statement
        catch (Exception Error) {
			sh '''
						
text="
Hi
						
Blackduck analysis for ${REPOSITORY_NAME} has failed. Please check
					
Build URL : ${BUILD_URL}
Thanks
"
						echo "$text" > mailBody.txt
						
						cat mailBody.txt | mail -s "${BUILD_DISPLAY_NAME}-BLACKDUCK - ${BUILD_NUMBER} has failed" -r 'buildmgr@parallelwireless.com' releng@parallelwireless.com
			'''
			throw Error
			currentBuild.result = 'FAILURE'
        }//closing catch statement
		finally{
			cleanWs()
		}
	}//closing dir varcode block
}//end of timestamps
}//end of node

def error_check()
{
	script {
		def logz = currentBuild.rawBuild.getLog(10000000);
		def errorKeyword1 = logz.find { it.contains('FAILURE_SCAN') }
		def errorKeyword2 = logz.find { it.contains('FAILURE_TIMEOUT') }
		if (errorKeyword1){
			error("Build failed due to $errorKeyword1")
		}
		if (errorKeyword2) {
			error("Build failed due to $errorKeyword2")
		}
	}
}

def network()
{
	dir('network'){
		sh '''
		cd hng/ci_scripts/build/
		export GIT_COMMIT=$(git rev-parse HEAD)
		sh -xe ci-build.sh ${GIT_COMMIT} ${PW_BRANCH}
		'''
	}
}
def vru4gphy()
{
	dir('vru-4g-phy'){
		sh '''
			export GIT_COMMIT=$(git rev-parse HEAD)
			sh -xe ci-build.sh
		'''
	}
}
def vru3gphy()
{
	dir('vru-3g-phy'){
		sh '''
			export GIT_COMMIT=$(git rev-parse HEAD)
			sh -xe ci-build.sh
		'''
	}
}
def vru2gphy()
{
	dir('vru-2g-phy'){
		sh '''
			export GIT_COMMIT=$(git rev-parse HEAD)
			sh -xe ci-build.sh
		'''
	}
}
def corestacks(){
	dir('core-stacks'){
	    def uid = sh(label: "Read user UID", returnStdout: true, script: "id -u").trim()
        def gid = sh(label: "Read user GID", returnStdout: true, script: "id -g").trim()
        def group = sh(label: "Read user group name", returnStdout: true, script: "id -gn").trim()
        def current_dir = pwd()

        image = docker.build(
            "core-stacks:core-stacks",
                "--build-arg HOME=${HOME} \
                 --build-arg UID=${uid} \
                 --build-arg USER=${USER} \
                 --build-arg GID=${gid} \
                 --build-arg GROUP=${group} \
                 --build-arg PWD=${current_dir} \
                 --build-arg BRANCH=${PW_BRANCH} \
                 -f docker/Dockerfile.user docker"
        )
		image.inside('-v"${HOME}":${HOME}') {
                sh 'make fdd.x86.install.8'
        }
		
	}
}
def osmo2g(){
	dir('osmo2g'){
        def uid = sh(label: "Read user UID", returnStdout: true, script: "id -u").trim()
        def gid = sh(label: "Read user GID", returnStdout: true, script: "id -g").trim()
        def group = sh(label: "Read user group name", returnStdout: true, script: "id -gn").trim()
        def current_dir = pwd()
        image = docker.build(
            "osmo2g:osmo2g",
            "--build-arg HOME=${HOME} \
             --build-arg UID=${uid} \
             --build-arg USER=${USER} \
             --build-arg GID=${gid} \
             --build-arg GROUP=${group} \
             --build-arg PWD=${current_dir} \
             -f docker/Dockerfile.user docker"
        )
		image.inside('-v"${HOME}":${HOME}') {
            sh 'make osmo-2g.dist'
        }
	}
}
def twogstack(){
	dir('2g-stack'){
		def uid = sh(label: "Read user UID", returnStdout: true, script: "id -u").trim()
        def gid = sh(label: "Read user GID", returnStdout: true, script: "id -g").trim()
        def group = sh(label: "Read user group name", returnStdout: true, script: "id -gn").trim()
        def current_dir = pwd()
        image = docker.build(
            "2g-stack:2g-stack",
            "--build-arg HOME=${HOME} \
             --build-arg UID=${uid} \
             --build-arg USER=${USER} \
             --build-arg GID=${gid} \
             --build-arg GROUP=${group} \
             --build-arg PWD=${current_dir} \
             -f docker/Dockerfile.user docker"
        )
		image.inside('-v"${HOME}":${HOME}') {
            sh """
				pwd
				ls
				make -C 2g-stack 2g.dist
			"""
        }
	}
}
def core()
{
	dir('core/vru'){
		sh """
			sh -xe ci-build.sh
		"""
	}
}
def nodeh()
{
	dir('nodeh'){
		def uid = sh(label: "Read user UID", returnStdout: true, script: "id -u").trim()
        def gid = sh(label: "Read user GID", returnStdout: true, script: "id -g").trim()
        def group = sh(label: "Read user group name", returnStdout: true, script: "id -gn").trim()
        def current_dir = pwd()

        image = docker.build(
            "nodeh:nodeh",
            "--build-arg HOME=${HOME} \
             --build-arg UID=${uid} \
             --build-arg USER=${USER} \
             --build-arg GID=${gid} \
             --build-arg GROUP=${group} \
             --build-arg PWD=${current_dir} \
             -f docker/Dockerfile.user docker"
        )
        image.inside('-v"${HOME}":${HOME}') {
            // new setup process (cmake)
            dir("source") {
                sh 'rm -rf ../build_li32 ../build_li64 ../build_hw ../build_sources ../trace'
                sh './setup_hw -c 900'
                sh 'source /opt/intel/system_studio_2019/bin/compilervars.sh intel64; ./setup_hw -t -p8'
            }
	    }
    }
}
def cwsrrh(){
	sh """
	export repository_slug="cws-rrh"
	./cws-rrh/build.sh 2g-ceva
	./cws-rrh/build.sh 3g-ceva
	"""
}
def pnfvnf(){
	dir('pnf-vnf'){
	    def uid = sh(label: "Read user UID", returnStdout: true, script: "id -u").trim()
        def gid = sh(label: "Read user GID", returnStdout: true, script: "id -g").trim()
        def group = sh(label: "Read user group name", returnStdout: true, script: "id -gn").trim()
        def current_dir = pwd()

        image = docker.build(
            "pnf-vnf:pnf-vnf",
            "--build-arg HOME=${HOME} \
             --build-arg UID=${uid} \
             --build-arg USER=${USER} \
             --build-arg GID=${gid} \
             --build-arg GROUP=${group} \
             --build-arg PWD=${current_dir} \
             -f docker/Dockerfile.user docker"
        )
                    image.inside('-v"${HOME}":${HOME}') {
                        dir("PW/product") {
                            def uncrustify_ignore = "\
                                -not -path '*/do/*' \
                                -not -path '*/import/*' \
                                -not -path '*/common/codecs/interface/*' \
                                -not -path '*/tests/*' \
                                -not -path '*/framework/logging/interface/loggingUtils_if.hpp' \
                                -not -path '*/pnf/downlink/module/decodeFsm.cpp' \
                                -not -path '*/pnf/downlink/module/decodeMessage.cpp' \
                                -not -path '*/pnf/downlink/module/downlinkP7.cpp' \
                                -not -path '*/pnf/uplink/module/encode.cpp' \
                                -not -path '*/pnf/uplink/module/uplink.cpp' \
                                -not -path '*/pnf/uplink/module/discardTimer.cpp' \
                                -not -path '*/pnf/uplink/module/tl_kheap.h' \
                                -not -path '*/pnf/main/module/pnfMain.cpp' \
                                -not -path '*/pnf/main/module/tl_kheap.h' \
                                -not -path '*/vnf/commsUl/module/commsUl.hpp' \
                                -not -path '*/vnf/commsUl/module/commsUlHandler.cpp' \
                                -not -path '*/vnf/commsUl/module/decode.cpp' \
                                -not -path '*/vnf/commsDl/module/commsDlHandler.cpp' \
                                "
                            def uncrustify_files = sh(
                                label: "Find files",
                                script: "\
                                    find -type f \
                                    -regextype posix-extended \
                                    -regex '.*\\.[ch](pp)?\$' \
                                    ${uncrustify_ignore} \
                                    -printf '%p ' \
                                ",
                                returnStdout: true
                            )
                            
                            sh(
                                label: "Run uncrustify",
                                script: "\
                                    ../../tools/uncrustify/uncrustify --check \
                                    -c ../../tools/uncrustify/accelleran.cfg \
                                    ${uncrustify_files} \
                                "
                            )
                        }
                    }
                    image.inside('-v"${HOME}":${HOME}') {
                        full_hash = sh(
                            label: "Get short commit hash",
                            returnStdout: true,
                            script: "git log --format=format:%H -n 1"
                        ).trim()


                        def threadCount = sh(
                            label: "Read jobs count",
                            returnStdout: true,
                            script: "nproc --all"
                        ).trim()
                        
                        dir("PW/product") {
                            sh(
                                label: "Build TTCN Test",
                                script: "\
                                    scons -j${threadCount} \
                                    --buildApplication=APPL-FDD \
                                    --buildMode=CONTINUOUS \
                                    --buildType=TTCNTEST \
                                    --logSeverity=DEBUG_SEVERITY \
                                    --wls-dpdk \
                                    pwApplExe \
                                "
                            )

                            sh(
                                label: "Build Product",
                                script: "\
                                    scons -j${threadCount} \
                                    --buildApplication=APPL-FDD \
                                    --buildMode=CONTINUOUS \
                                    --buildType=PRODUCTION \
                                    --logSeverity=ERROR_SEVERITY \
                                    --wls-dpdk \
                                    pwApplExe \
                                "
                            )
						}
					}
	}
}
def nrstack(){
	dir('nr-stack'){
                    def uid = sh(label: "Read user UID", returnStdout: true, script: "id -u").trim()
                    def gid = sh(label: "Read user GID", returnStdout: true, script: "id -g").trim()
                    def group = sh(label: "Read user group name", returnStdout: true, script: "id -gn").trim()
                    def current_dir = pwd()

                    image = docker.build(
                        "nr-stacks:nr-stacks",
                        "--build-arg HOME=${HOME} \
                         --build-arg UID=${uid} \
                         --build-arg USER=${USER} \
                         --build-arg GID=${gid} \
                         --build-arg GROUP=${group} \
                         --build-arg PWD=${current_dir} \
                         -f docker/Dockerfile.user docker"
                    )
                    image.inside('-v"${HOME}":${HOME}') {
                        /* fail on error
                        sh """
                            sh -xe build.sh all sa intel
                        """
                        */
                        sh './build.sh all sa intel'
                    }
					image.inside('-v"${HOME}":${HOME}') {
                        full_hash = sh(
                            label: "Get full commit hash",
                            returnStdout: true,
                            script: "git log --format=format:%H -n 1"
                        ).trim()
                        /* fail on error
                        sh """
                            sh -xe build.sh all sa host
                        """
                        */
                        sh 'free -g'
                        sh './build.sh all sa host'
                    }
	
	}
}
def pwconfig(){
	dir('pwconfig/deploy'){
        commit_time = sh (script: 'TZ=UTC date -d @`git show -s --format=%ct ${commit_hash}` +"%Y%m%d.%H%M"',returnStdout: true).trim()
        short_commit_hash = sh (script: 'git rev-parse --short=8 HEAD',returnStdout: true).trim()
        echo "commit_hash $commit_hash $commit_time"
        sh """
			sh -xe ci-build.sh staging ${PW_BRANCH} ${short_commit_hash} ${commit_time}
        """
	}
}
def pwgui(){
	dir('pwgui/deploy'){
        echo "branch ${PW_BRANCH}"
        commit_time = sh (script: 'date -d @`git show -s --format=%ct HEAD` +"%Y%m%d.%H%M"',returnStdout: true).trim()
        short_commit_hash = sh (script: 'git rev-parse --short=8 HEAD',returnStdout: true).trim()
        echo "commit_hash $commit_time"
        echo "Calling the Docker Build Script..."
        sh """
			sh -xe ci-build.sh ${PW_BRANCH} ${short_commit_hash} ${commit_time}
        """	
	}
}
def rtmonitoring(){
	dir('rt-monitoring'){
	
	}
}


def near_rtric(){
	dir('near_rtric'){
            sh """
            git submodule update --init
			cd ci-build
			./ci-build.sh app-all
            """	
	}
}

def corestacksphy(){
	dir('core-stacks-phy/4gPhy/'){
            sh '''
            echo "building arm"
            ./ci-build.sh
            '''
        }    
}
def xappdev(){
	dir('xapp-dev'){
	
	}
}