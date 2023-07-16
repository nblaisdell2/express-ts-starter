#!/bin/bash

awsAccountID=$1
awsRegion=$2
awsECRRepoName=$3
dockerContainerName=$3
awsLambdaName=$3
awsLambdaExecRoleArn=$4
awsAPIGatewayName=$3-API
awsAPIGatewayDesc="$3-API Description"




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
  echo "  Creating..."
  aws lambda create-function --function-name $awsLambdaName --package-type Image --code ImageUri=$awsAccountID.dkr.ecr.$awsRegion.amazonaws.com/$dockerContainerName:latest --role $awsLambdaExecRoleArn >/dev/null
  sleep 15
  initVersion=$(aws lambda publish-version --function-name $awsLambdaName --description "Initial Version" | jq -r .Version)
  aws lambda create-alias --function-name $awsLambdaName --name latest --function-version $initVersion --description "Latest version" >/dev/null



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

rm aws.json