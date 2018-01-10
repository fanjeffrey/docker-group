DOCKER_IMAGE_NAME=$1

# If script run to error, exist -1;
function _do() 
{
        "$@" || { echo "exec failed: ""$@"; exit -1; }
}

build_image(){
    echo "${DOCKER_PASSWORD}" | _do docker login -u="${DOCKER_USERNAME}" --password-stdin
    _do docker build -t "${DOCKER_IMAGE_NAME}" .
    testBuildImage=$(docker images | grep "${DOCKER_IMAGE_NAME}")
    if [ -z "${testBuildImage}" ]; then 
        echo "FAILED - Build fail!!!"
        exit 1
    else
        echo "${testBuildImage}"
        echo "PASSED - Build Successfully!!!."
    fi
}

setTag_push_rm(){
    echo "TAG: ${TAG}"
    _do docker tag "${DOCKER_IMAGE_NAME}" "${DOCKER_USERNAME}"/"${DOCKER_IMAGE_NAME}":"${TAG}"
    testBuildImage=$(docker images | grep "$TAG")
    if [ -z "${testBuildImage}" ]; then 
        echo "FAILED - Set TAG Failed!!!"
        exit 1
    else
        echo "${testBuildImage}"
        echo "PASSED - Set TAG Successfully!."
    fi
    _do docker push "${DOCKER_USERNAME}"/"${DOCKER_IMAGE_NAME}":"${TAG}"
    echo "PASSED - Pushed  ${DOCKER_USERNAME}/${DOCKER_IMAGE_NAME}:${TAG} Successfully!."
    echo "INFORMATION: Before rmi - docker images"
    _do docker images
    echo "INFORMATION: RM ""${DOCKER_USERNAME}"/"${DOCKER_IMAGE_NAME}":"${TAG}"
    _do docker rmi "${DOCKER_USERNAME}"/"${DOCKER_IMAGE_NAME}":"${TAG}"
    echo "INFORMATION: After rmi - docker images"
    _do docker images
}

echo "================================================="
echo "Stage1 - Verify Dockerfile"
echo "INFORMATION: Start to Verifiy Dockerfile......"
test_Dockerfile
echo "================================================="

echo "Stage2 - Build Image"
echo "INFORMATION: Start to Build......"
build_image
echo "================================================="

echo "Stage3 - Set Tag and Push"
echo "Build Number: ${TRAVIS_BUILD_NUMBER}"
echo "TRAVIS_EVENT_TYPE: ${TRAVIS_EVENT_TYPE}"
echo "TRAVIS_COMMIT_MESSAGE: ${TRAVIS_COMMIT_MESSAGE}"

pushed="false"
if [ "$TRAVIS_EVENT_TYPE" == "push" ]; then
    echo "INFORMATION: This is a PUSH/MERGE......"
    MegerPull="Merge pull"
    Version="Version:"    
    # get the line which contains "Version" form commit message.
    version=$(echo "${TRAVIS_COMMIT_MESSAGE}" | grep "Version") 
    if [ -n "${version}" ]; then
            echo "INFORMATION: Commit Message contains version......"
            # remove left chars since ":"
            TAG=${version##*:}
            echo "INFORMATION: Set TAG as ""${version##*:}"" and push......" 
            setTag_push_rm
            pushed="true"
    fi 
    # commit message start with "Merge pull"
    if [[ ${TRAVIS_COMMIT_MESSAGE} == $MegerPull* ]]; then
        echo "INFORMATION: Commit Message contains Merge pull......"
        TAG="latest"
        echo "INFORMATION: Set TAG as latest and push......"
        setTag_push_rm
        pushed="true"       
    fi    
else
    if [ "$TRAVIS_EVENT_TYPE" == "pull_request" ]; then
        # this is a PR.
	    echo "INFORMATION: This is a PULL REQUEST......"
        SignOff="#sign-off"
        PR_TITLE=$(curl https://api.github.com/repos/"${TRAVIS_REPO_SLUG}"/pulls/"${TRAVIS_PULL_REQUEST}" | grep '"title":')
        echo "PR_TITLE:""${PR_TITLE}"
        signoff=$(echo "${PR_TITLE}" | grep "${SignOff}")  
	    
        # if commit message of this PR contains "#sign-off", set tag as latest, push.
        if [ -n "${signoff}" ]; then
            echo "INFORMATION: PR Title contains #sign-off......"
            # get clear content. Prepare to compare with SignOff
            signoff=${signoff##*' '}     
            signoff=${signoff//'"'/''}
            signoff=${signoff//','/''}
            TAG="latest"
	        echo "INFORMATION: Set TAG as latest and push......"
            setTag_push_rm
            pushed="true"
        fi
        # if commit message of this PR contains version tag, set tag and push.
        if [ "$signoff" != "$SignOff" ]; then  
            echo "INFORMATION: PR Title contains #sign-off and version......"  
            TAG=${signoff#*:}
            echo "INFORMATION: Set TAG as ""${signoff#*:}"" and push......"
            setTag_push_rm
            pushed="true" 
        fi
    fi
        
fi
if [ "${pushed}" == "false" ]; then
        TAG="${TRAVIS_BUILD_NUMBER}"
        echo "INFORMATION: Set TAG as ""${TRAVIS_BUILD_NUMBER}""and push......"
        setTag_push_rm
fi

echo "================================================="
echo "Stage4 - PULL and Verify"
echo "INFORMATION: Start to Pull ""${DOCKER_USERNAME}"/"${DOCKER_IMAGE_NAME}":"${TAG}"
echo "INFORMATION: Before Pull - docker images"
_do docker images
_do docker run -d --rm -p 80:80 $DOCKER_USERNAME/${DOCKER_IMAGE_NAME}:"$TAG"
echo "INFORMATION: After Pull - docker images"
_do docker images
testBuildImage=$(docker images | grep "${TAG}")
    if [ -z "$testBuildImage" ]; then 
        echo "FAILED - Docker pull and run Failed!!!"
        docker images
        exit 1
    else
        echo "$testBuildImage"
        echo "PASSED - Docker image pull and run Successfully!. You can manually verify it!"
    fi
echo "================================================="


# Everything is OK, return 0
exit 0
