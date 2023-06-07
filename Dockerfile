# Base image for working with AWS ECR
FROM public.ecr.aws/lambda/nodejs:16

# Set the working directory to the one
# that the Lambda will expect our code to be in
#   ${LAMBDA_TASK_ROOT} = '/var/task'
WORKDIR ${LAMBDA_TASK_ROOT}

# Copy all the source files into the working directory
COPY . .

# With package.json included in the last step, run "npm install"
# to install our needed dependencies for the project
RUN npm install

# Then, since we're using TypeScript, run the "build" command to 
# transpile the code into JavaScript
RUN npm run build

# Then, do some cleanup
RUN cp -r ./dist/* .
RUN rm -rf ./dist

# Lastly, set the CMD to your handler 
#   (could also be done as a parameter override outside of the Dockerfile)
CMD [ "server-lambda.handler" ]
