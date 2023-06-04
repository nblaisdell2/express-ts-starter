FROM public.ecr.aws/lambda/nodejs:16

WORKDIR ${LAMBDA_TASK_ROOT}

COPY . .

RUN npm install
# RUN npm install express
# RUN npm install aws-serverless-express

RUN npm run build

# Copy function code
COPY ./dist .

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "server-lambda.handler" ]
