echo "Show ENV Paramters:"

# TRAVIS_ALLOW_FAILURE: 
# set to true if the job is allowed to fail.
# set to false if the job is not allowed to fail.
echo "TRAVIS_ALLOW_FAILURE: $TRAVIS_ALLOW_FAILURE"
# TRAVIS_BRANCH: 
# for push builds, or builds not triggered by a pull request, this is the name of the branch.
# for builds triggered by a pull request this is the name of the branch targeted by the pull request.
# for builds triggered by a tag, this is the same as the name of the tag (TRAVIS_TAG). 
echo "TRAVIS_BRANCH: $TRAVIS_BRANCH"
# TRAVIS_BUILD_DIR: The absolute path to the directory where the repository being built has been copied on the worker.
echo "TRAVIS_BUILD_DIR: $TRAVIS_BUILD_DIR"
# TRAVIS_BUILD_ID: The id of the current build that Travis CI uses internally.
echo "TRAVIS_BUILD_ID: $TRAVIS_BUILD_ID"
# TRAVIS_BUILD_NUMBER: The number of the current build (for example, “4”).
echo "TRAVIS_BUILD_NUMBER: $TRAVIS_BUILD_NUMBER"
# TRAVIS_COMMIT: The commit that the current build is testing.
echo "TRAVIS_COMMIT: $TRAVIS_COMMIT"
# TRAVIS_COMMIT_MESSAGE: The commit subject and body, unwrapped.
echo "TRAVIS_COMMIT_MESSAGE: $TRAVIS_COMMIT_MESSAGE"
# TRAVIS_COMMIT_RANGE: The range of commits that were included in the push or pull request. (Note that this is empty for 
# builds triggered by the initial commit of a new branch.)
echo "TRAVIS_COMMIT_RANGE: $TRAVIS_COMMIT_RANGE"
# TRAVIS_EVENT_TYPE: Indicates how the build was triggered. One of push, pull_request, api, cron.
echo "TRAVIS_EVENT_TYPE: $TRAVIS_EVENT_TYPE"
# TRAVIS_JOB_ID: The id of the current job that Travis CI uses internally.
echo "TRAVIS_JOB_ID: $TRAVIS_JOB_ID"
# TRAVIS_JOB_NUMBER: The number of the current job (for example, “4.1”).
echo "TRAVIS_JOB_NUMBER: $TRAVIS_JOB_NUMBER"
# TRAVIS_OS_NAME: On multi-OS builds, this value indicates the platform the job is running on. Values are linux and osx currently, 
# to be extended in the future.
echo "TRAVIS_OS_NAME: $TRAVIS_OS_NAME"
# TRAVIS_PULL_REQUEST: The pull request number if the current job is a pull request, “false” if it’s not a pull request.
echo "TRAVIS_PULL_REQUEST: $TRAVIS_PULL_REQUEST"
# TRAVIS_PULL_REQUEST_BRANCH: 
# if the current job is a pull request, the name of the branch from which the PR originated.
# if the current job is a push build, this variable is empty ("").
echo "TRAVIS_PULL_REQUEST_BRANCH: $TRAVIS_PULL_REQUEST_BRANCH"
# TRAVIS_PULL_REQUEST_SHA: 
# if the current job is a pull request, the commit SHA of the HEAD commit of the PR.
# if the current job is a push build, this variable is empty ("").
echo "TRAVIS_PULL_REQUEST_SHA: $TRAVIS_PULL_REQUEST_SHA"
# TRAVIS_PULL_REQUEST_SLUG: 
# if the current job is a pull request, the slug (in the form owner_name/repo_name) of the repository from which the PR originated.
# if the current job is a push build, this variable is empty ("").
echo "TRAVIS_PULL_REQUEST_SLUG: $TRAVIS_PULL_REQUEST_SLUG"
# TRAVIS_REPO_SLUG: The slug (in form: owner_name/repo_name) of the repository currently being built.
echo "TRAVIS_REPO_SLUG: $TRAVIS_REPO_SLUG"
# TRAVIS_SECURE_ENV_VARS: 
# set to true if there are any encrypted environment variables.
# set to false if no encrypted environment variables are available.
echo "TRAVIS_SECURE_ENV_VARS: $TRAVIS_SECURE_ENV_VARS"
# TRAVIS_SUDO: true or false based on whether sudo is enabled.
echo "TRAVIS_SUDO: $TRAVIS_SUDO"
# TRAVIS_TEST_RESULT: is set to 0 if the build is successful and 1 if the build is broken.
echo "TRAVIS_TEST_RESULT: $TRAVIS_TEST_RESULT"
# TRAVIS_TAG: If the current build is for a git tag, this variable is set to the tag’s name.
echo "TRAVIS_TAG: $TRAVIS_TAG"

TRAVIS_EVENT_TYPE="push"
commit_sha=""
DOCKER_IMAGE_NAME=""
DOCKER_IMAGE_VERSION=""
docker_count=0

get_files_from_commit(){
    curl https://api.github.com/repos/"${TRAVIS_REPO_SLUG}"/commits/"$commit_sha" | grep '"filename":' > commit_files.txt
    sed -i 's/'\"filename\":'/''/g' commit_files.txt
    sed -i 's/'\"'/''/g' commit_files.txt
    sed -i 's/','/''/g' commit_files.txt
    sed -i 's/' '/''/g' commit_files.txt
    echo "====================================================================================="
    echo "Below files are changed:"
    cat commit_files.txt
    
    last_docker_image_name="nothing"
    last_docker_image_version="nothing"
    line_count=1
    lines=$(wc -l commit_files.txt)
    lines=${lines%%' '*}
    echo "Total lines: "${lines}
    while (( $line_count<=$lines )) 
    do
	    echo "Deal with "$line_count" line:"
        current_line=$(sed -n "${line_count}p" commit_files.txt)
        echo "Current line: "${current_line}
        # The normal line should be DOCKER_IMAGE_NAME/DOCKER_IMAGE_VERSION/filename
        # The count of '/' should be >= 2
        slash_count=$(echo ${current_line} | grep -o '/' | wc -l)		
        if ((slash_count<2)); then
            echo "INFORMATION - This file doesn't related with any Docker."        
        else			
            current_docker_image_name=${current_line%%/*}
            current_docker_image_version=${current_line#*/}
            current_docker_image_version=${current_docker_image_version%%/*}			
            if [[ "$current_docker_image_name" != "$last_docker_image_name" || "$current_docker_image_version" != "$last_docker_image_version" ]]; then
                docker_count=`expr $docker_count + 1`                
                docker_image_name[$docker_count]=$current_docker_image_name
				docker_image_version[$docker_count]=$current_docker_image_version
				last_docker_image_name=$current_docker_image_name
                last_docker_image_version=$current_docker_image_version                 
           fi 
        fi
	    line_count=`expr $line_count + 1`
    done
	rm commit_files.txt
}

if [ "$TRAVIS_EVENT_TYPE" == "push" ]; then
    commit_sha=$TRAVIS_COMMIT
#    TRAVIS_REPO_SLUG=leonzhang77/docker-group
#    commit_sha=d6cf2b5859abd88dde0ef5694dd2d9cbbbffd938
    get_files_from_commit
fi

dockers=$docker_count
echo "dockers: "${dockers}
if [[ "${dockers}" == "0" ]]; then
    echo "This time, doesn't change any files related with docker, no need to verify."
    exit 0;
fi

echo "======================================================================================"
echo "INFORMATION - This time, we need to verify below dockers:"
echo " "
echo " "
docker_count=1
while (( $docker_count<=$dockers))
do       
    echo ${docker_image_name["${docker_count}"]}"/"${docker_image_version["${docker_count}"]}       
    docker_count=`expr $docker_count + 1`
done
echo " "
echo " "

echo "======================================================================================"
echo "INFORMATION - Start to Verify Dockers:"
# Verify Docker files.
docker_count=1
while (( $docker_count<=$dockers))
do     
	docker_folder=${docker_image_name["${docker_count}"]}"/"${docker_image_version["${docker_count}"]}
	echo "folder: "$docker_folder
	blank_count=0
    blank_count=$(echo ${docker_folder} | grep -o ' ' | wc -l)    
    if ((blank_count>0)); then
        echo "ERROR - blank char should not be include in folder name!"
        exit -1
    fi
	#Is this commit remove a Image/Version? If yes, we can skip this step.
    if test ! -d $docker_folder; then
        echo "INFORMATION: This commit Remove "${docker_image_name["${docker_count}"]}"/"${docker_image_version["${docker_count}"]}" !"
    else      
        ./travis-script/test-dockerfile.sh ${docker_image_name["${docker_count}"]} ${docker_image_version["${docker_count}"]}
		test_result=$?		
		if ((test_result!=0)); then
			echo "ERROR - Please double check......"
			exit -1
		fi
    fi
    docker_count=`expr $docker_count + 1`
done


# Everything is OK, return 0
exit 0

