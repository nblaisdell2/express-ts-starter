#!/bin/bash

echo -ne "AWS Account ID: "
read awsAccountID

echo -ne "AWS Region (us-east-1): "
read awsRegion

echo -ne "AWS ECR Repo Name: "
read awsECRRepoName

echo -ne "Container Name: "
read dockerContainerName

echo -ne "AWS Lambda Name: "
read awsLambdaName

echo -ne "AWS Lambda Exec Role ARN: "
read awsLambdaExecRoleArn

echo -ne "AWS API Gateway Name: "
read awsAPIGatewayName

echo -ne "AWS API Gateway Description: "
read awsAPIGatewayDesc




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
else
  echo "  ECR Repository '$awsECRRepoName' already created..."
fi

# Build the Docker container and set it up (tag the container) 
# to get ready to be uploaded to ECR. Then, push to ECR.
echo ===================================
echo BUILDING DOCKER CONTAINER
echo ===================================
echo "  Building container..."
docker build -t $dockerContainerName:latest .
echo "  Tagging container..."
docker tag docker-image:test $awsAccountID.dkr.ecr.$awsRegion.amazonaws.com/$dockerContainerName:latest
echo "  Pushing container to ECR..."
docker push $awsAccountID.dkr.ecr.$awsRegion.amazonaws.com/$dockerContainerName:latest


echo ===================================
echo CREATING LAMBDA FUNCTION
echo ===================================
aws lambda list-functions > aws.json
lambdaCount=$(jq '.Functions[] | select(.FunctionName == "'$awsLambdaName'") | length' aws.json)

if [[ $lambdaCount -eq 0 ]]
then
  echo "  Creating..."
  aws lambda create-function --function-name $awsLambdaName --package-type Image --code ImageUri=$awsAccountID.dkr.ecr.$awsRegion.amazonaws.com/$dockerContainerName:latest --role $awsLambdaExecRoleArn >/dev/null
else
  echo "  Lambda Function '$awsLambdaName' already exists..."
fi

# # Update Lambda function
# aws lambda update-function-code --region $awsRegion --function-name $awsLambdaName --image-uri $awsAccountID.dkr.ecr.$awsRegion.amazonaws.com/$dockerContainerName:latest

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

rm aws.json

# echo awsAccountID {$awsAccountID}
# echo awsRegion {$awsRegion}
# echo awsECRRepoName {$awsECRRepoName}
# echo dockerContainerName {$dockerContainerName}
# echo awsLambdaName {$awsLambdaName}
# echo awsLambdaExecRoleArn {$awsLambdaExecRoleArn}
# echo awsAPIGatewayName {$awsAPIGatewayName}
# echo awsAPIGatewayDesc {$awsAPIGatewayDesc}