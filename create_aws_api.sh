#!/bin/bash

awsAccountID=$1
awsRegion=$2
awsECRRepoName=$3
dockerContainerName=$3
awsLambdaName=$3
awsCodeBuildProjName=$3
awsLambdaExecRoleArn=$4
awsGitHubRepoURL=$5
awsAPIGatewayName=$3
awsAPIGatewayDesc="$3 Description"

# TODO: Add better logging to script



echo ===================================
echo CONNECTING TO AWS ECR
echo ===================================
# login to ECR for Docker
echo "  Logging into ECR..."
aws ecr get-login-password --region $awsRegion | docker login --username AWS --password-stdin $awsAccountID.dkr.ecr.$awsRegion.amazonaws.com >/dev/null

# Get the list of current repositories in ECR for this account
# and check to see if this repo already exists
# If not, create the ECR repo. Otherwise, just continue.
aws ecr describe-repositories > aws.json
repoCount=$(jq '.repositories[] | select(.repositoryName == "'$awsECRRepoName'") | length' aws.json)

if [[ $repoCount -eq 0 ]]
then
  echo "  Creating ECR Repository..."
  aws ecr create-repository --repository-name $awsECRRepoName --image-scanning-configuration scanOnPush=true --image-tag-mutability MUTABLE >/dev/null

  # Build the Docker container and set it up (tag the container) 
  # to get ready to be uploaded to ECR. Then, push to ECR.
  echo ===================================
  echo BUILDING DOCKER CONTAINER
  echo ===================================
  echo "  Building container..."
  docker build -t $dockerContainerName:latest .
  echo "  Tagging container..."
  docker tag $dockerContainerName:latest $awsAccountID.dkr.ecr.$awsRegion.amazonaws.com/$dockerContainerName:latest
  echo "  Pushing container to ECR..."
  docker push $awsAccountID.dkr.ecr.$awsRegion.amazonaws.com/$dockerContainerName:latest





  echo ===================================
  echo CREATING LAMBDA FUNCTION
  echo ===================================
  echo "  Creating Lambda..."
  aws lambda create-function --function-name $awsLambdaName --package-type Image --code ImageUri=$awsAccountID.dkr.ecr.$awsRegion.amazonaws.com/$dockerContainerName:latest --role $awsLambdaExecRoleArn >/dev/null
  sleep 15
  initVersion=$(aws lambda publish-version --function-name $awsLambdaName --description "Initial Version" | jq -r .Version)
  aws lambda create-alias --function-name $awsLambdaName --name latest --function-version $initVersion --description "Latest version" >/dev/null





  echo ===================================
  echo CREATING CODEBUILD PROJECT
  echo ===================================
  # create codebuild service-role and get ARN here to be used in the next section
  awsCodeBuildRoleName="codebuild-$awsLambdaName-role"
  awsCodeBuildRoleArn=$(aws iam create-role --role-name "$awsCodeBuildRoleName" --assume-role-policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"codebuild.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}" | jq -r .Role.Arn)
  aws iam put-role-policy --role-name "$awsCodeBuildRoleName" --policy-name "codebuild-$awsLambdaName-policy" --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"Auto0\",\"Effect\":\"Allow\",\"Action\":[\"codedeploy:*\",\"codebuild:*\",\"ecr:*\",\"logs:*\",\"lambda:*\"],\"Resource\":\"*\"}]}" >/dev/null
  sleep 10
  aws codebuild create-project --name $awsCodeBuildProjName --source "{\"type\": \"GITHUB\", \"location\": \"$awsGitHubRepoURL\", \"reportBuildStatus\": true}" --artifacts "{\"type\": \"NO_ARTIFACTS\"}" --environment "{\"type\": \"LINUX_CONTAINER\", \"image\": \"aws/codebuild/amazonlinux2-x86_64-standard:5.0\", \"computeType\": \"BUILD_GENERAL1_SMALL\", \"privilegedMode\": true, \"imagePullCredentialsType\": \"CODEBUILD\", \"environmentVariables\": [{\"name\": \"awsRegion\", \"value\": \"$awsRegion\", \"type\": \"PLAINTEXT\"},{\"name\": \"awsAccountID\", \"value\": \"$awsAccountID\", \"type\": \"PLAINTEXT\"},{\"name\": \"dockerContainerName\", \"value\": \"$dockerContainerName\", \"type\": \"PLAINTEXT\"}]}" --service-role "$awsCodeBuildRoleArn" >/dev/null
  


  echo ===================================
  echo CREATING CODEDEPLOY PROJECT
  echo ===================================
  awsCodeDeployRoleName="codedeploy-$awsLambdaName-role"
  awsCodeDeployRoleArn=$(aws iam create-role --role-name "$awsCodeDeployRoleName" --assume-role-policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"codedeploy.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}" | jq -r .Role.Arn)
  aws iam attach-role-policy --role-name $awsCodeDeployRoleName --policy-arn arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicFullAccess >/dev/null
  aws iam attach-role-policy --role-name $awsCodeDeployRoleName --policy-arn arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda >/dev/null
  sleep 10

  aws deploy create-application --application-name $awsLambdaName-deploy --compute-platform Lambda >/dev/null
  aws deploy create-deployment-group --application-name $awsLambdaName-deploy --deployment-group-name $awsLambdaName-deploy-group --service-role-arn $awsCodeDeployRoleArn --deployment-style "{\"deploymentType\": \"BLUE_GREEN\", \"deploymentOption\": \"WITH_TRAFFIC_CONTROL\"}" >/dev/null





  echo ===================================
  echo CREATING API GATEWAY
  echo ===================================
  restApiID=$(aws apigateway create-rest-api --name $awsAPIGatewayName --description "$awsAPIGatewayDesc" --endpoint-configuration '{"types": ["REGIONAL"]}' | jq -r .id)

  resource1ID=$(aws apigateway get-resources --rest-api-id $restApiID | jq -r .items[0].id)
  resource2ID=$(aws apigateway create-resource --rest-api-id $restApiID --parent-id $resource1ID --path-part {proxy+} | jq -r .id)

  aws apigateway put-method --rest-api-id $restApiID --resource-id $resource1ID --http-method ANY --authorization-type NONE --request-parameters '{}' >/dev/null
  aws apigateway put-method --rest-api-id $restApiID --resource-id $resource2ID --http-method ANY --authorization-type NONE --request-parameters '{}' >/dev/null

  aws apigateway put-integration --region $awsRegion --rest-api-id $restApiID --resource-id $resource1ID --http-method ANY --type AWS_PROXY --content-handling CONVERT_TO_TEXT --integration-http-method POST --uri "arn:aws:apigateway:$awsRegion:lambda:path/2015-03-31/functions/arn:aws:lambda:$awsRegion:$awsAccountID:function:$awsLambdaName/invocations" >/dev/null
  aws apigateway put-integration-response --rest-api-id $restApiID --resource-id $resource1ID --http-method ANY --status-code 200 --response-templates '{}' >/dev/null
  aws apigateway put-method-response --rest-api-id $restApiID --resource-id $resource1ID --http-method ANY --status-code 200 --response-models '{"application/json": "Empty"}' >/dev/null

  aws apigateway put-integration --region $awsRegion --rest-api-id $restApiID --resource-id $resource2ID --http-method ANY --type AWS_PROXY --content-handling CONVERT_TO_TEXT --integration-http-method POST --uri "arn:aws:apigateway:$awsRegion:lambda:path/2015-03-31/functions/arn:aws:lambda:$awsRegion:$awsAccountID:function:$awsLambdaName/invocations" >/dev/null
  aws apigateway put-integration-response --rest-api-id $restApiID --resource-id $resource2ID --http-method ANY --status-code 200 --response-templates '{}' >/dev/null
  aws apigateway put-method-response --rest-api-id $restApiID --resource-id $resource2ID --http-method ANY --status-code 200 --response-models '{"application/json": "Empty"}' >/dev/null

  aws lambda add-permission --function-name $awsLambdaName --statement-id stmt_invoke_1 --action lambda:InvokeFunction --principal apigateway.amazonaws.com --source-arn arn:aws:execute-api:$awsRegion:$awsAccountID:$restApiID/*/*/ >/dev/null
  aws lambda add-permission --function-name $awsLambdaName --statement-id stmt_invoke_2 --action lambda:InvokeFunction --principal apigateway.amazonaws.com --source-arn arn:aws:execute-api:$awsRegion:$awsAccountID:$restApiID/*/*/* >/dev/null

  aws apigateway create-deployment --rest-api-id $restApiID --stage-name dev >/dev/null

  echo -ne "New API URL: "
  echo https://$restApiID.execute-api.$awsRegion.amazonaws.com/dev
else
  echo "AWS Infrastructure already created..."
fi

# Get all GH Secrets, find all variables starting with "ENV_",
# and create an object of environment variables to then
# use in the Update Lambda Config call
envVars="{"  
while read i; 
do 
  if [ "$envVars" == "{" ]; then
    item=$(echo "${i/ENV_/""}")    
  else
    item=$(echo ", ${i/ENV_/""}")
  fi

  envVars+="$item"
done <<< $(echo "$ALLMYSECRETS" | jq -r '. | to_entries[] | select(.key | startswith("ENV")) | (.key|tojson) + ": " + (.value|tojson)')
envVars+="}"

echo "Updating Lambda Environment Variables"
aws lambda update-function-configuration --function-name $dockerContainerName --environment "{ \"Variables\": $envVars }"

rm aws.json