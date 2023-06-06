# Express Boilerplate - TypeScript

This repository is a complete and functional Express app, which is built using TypeScript. This will allow me to start up a new Express app relatively easy in the future, with this as a starting point.

Since there are many times when I want to create an API, for various different purposes, having a starting point to immediately start implementing a new JavaScript API will greatly increase the speed of being able to do so.

As I have more use-cases for creating APIs using Express, I will continue to add to this repository, giving myself more functions to start with.

In order to get started using this boilerplate, simply clone or fork this repository, and start integrating your API using Express!

## Forking/Cloning

When using this as a starter project, perform the following steps:

1. Create a ".env" file, and add a PORT variable. - If not provided, the default is port 3000.
   <br/>
2. Install the dependencies for the project
   `npm install`
   <br/>
3. Run the project
   `npm run dev`

---

# Setup

The rest of this README will explain the process of creating this repository.

> Huge thanks to Colt Steele, whose video and explanation helped me to integrate TypeScript into an Express app! Check out their original repository and video here:
>
> - [Video: How To Use TypeScript With Express & Node](https://www.youtube.com/watch?v=qy8PxD3alWw)
> - [Colt's Repo - express-ts](https://github.com/Colt/express-ts) > <br/>

## Dependencies

`npm install express typescript @types/express @types/node nodemon rimraf concurrently dotenv http-errors`

- **express** / **@types/express** / **@types/node** - Brings in the code & types to work with ExpressJS
- **typescript** - Allows the use of TypeScript in the project
- **rimraf** - cli command which allows us to delete a directory "rm -rf or rimraf" when building the project
- **concurrently** - cli command which allows us (in a cross-platform way) to run two or more commands simultaneously
- **dotenv** - Allows us to make use of environment (.env) files to define hidden variables, like PORT
- **http-errors** - Library which allows us to handle errors

---

## Creating the Project

### Initializing the Project

1. Start in an empty directory, and initialize an npm project
   This will create the "package.json" file
   `npm init -y`

<br>

2. Create a _src_ directory, and create the following elements:
   - **app.ts** - This will create the Express app, and will be where we define our API endpoints (routers), and also handles errors
   - **server.ts** - This is a separate file, which will make use of the "app" variable exported from the <u>app.ts</u> file, and define the "listen" function, where we start up our server.
     - <u>**NOTE**</u>: This will be the file that is called by node, or whatever server it runs on, to start up the server
   - **routes (directory)** - This is a folder that will contain all of the different endpoint implementations, through the use of an Express Router.
     - The "GET / POST / PUT / DELETE" functions are defined and exported through these files, and are used in the <u>app.ts</u> file.

<br>

3. Add the following boilerplate for the simplest of Express applications into <u>app.ts</u>.
   We'll separate the code into their respective files later on:

```
// Imports the express library
const express = require("express");

// Defines a port # which our server will be run on
const port = 8000;

// Creates the Express app, which we can then use further below
const app = express();

// Using the Express app to define a "GET" endpoint on the index ("/" or homepage) URL of our server
// This will put "Hello from Express" directly onto the webpage, since we're using res.send()
app.get("/", (req, res) => {
    res.send("Hello from Express");
});

// Using the Express app to start up the server at a given port (8000, defined above)
// This will log a message to the console, and then run indefinitely until it is shut down
app.listen(port, () => {
    console.log(`Listening on port ${port}`);
});
```

### Integrating TypeScript

At this point, we're still using plain JavaScript in our TypeScript files, and not making use of the benefits of the types that TypeScript provides.

If they weren't installed earlier, make sure to install the following packages:
`npm install typescript @types/express @types/node`

From there, a lot of the type information will already be inferred by TypeScript, but for the purposes of being explicit, and getting a slightly better understanding of the types used for Express, I'll annotate each of the appropriate variables with the associated types.

```
// Imports the express library (in the TypeScript way)
import express, {Express, Request, Response} from "express";

// Defines a port # which our server will be run on
const port = 8000;

// Creates the Express app, which we can then use further below
//   Also, is now annotated with the appropriate "Express" type
const app: Express = express();

// Using the Express app to define a "GET" endpoint on the index ("/" or homepage) URL of our server
// This will put "Hello from Express" directly onto the webpage, since we're using res.send()
//   Also, is now annotated with the appropriate "Request/Response" types
app.get("/", (req: Request, res: Response) => {
    res.send("Hello from Express");
});

// Using the Express app to start up the server at a given port (8000, defined above)
// This will log a message to the console, and then run indefinitely until it is shut down
app.listen(port, () => {
    console.log(`Listening on port ${port}`);
});
```

### Building & Serving JavaScript Files

Now that we've converted to typescript (.ts) files, we'll no longer be able to run our server directly from Node, since it requires a JavaScript file. As a result, we'll need to "transpile" our TypeScript files into valid JavaScript files, and then have Node run those files.

First, we'll need to generate a TypeScript configuration (tsconfig.json) file using the follwing command:
`npx tsc --init`

That will generate a JSON file with many parameters, most of which are commented out, which define how TypeScript should work within this particular project.
The one variable we will change is the "outDir" parameter, which defines where the transpiled JavaScript files should be outputted to within our project directory.

- In our case, we'll be switching this to `"./dist"`, which will create a "dist" folder in our top-level folder, and then put the generated JavaScript files in there.
  - **NOTE**: These are the files that need to be executed using Node

Then, to run our server like we did before, we'll run the following two commands:

- The first command runs the TypeScript compiler, and transpiles our files into the "dist" folder
- The second command uses node to run our outputted app.js file from within the "dist" folder

```
npx tsc
node dist/app.js
```

### Simplifying Building with npm Scripts

Since it would be a hassle to run these two commands every time we want to rebuild our project, we can make use of the "scripts" section in our _package.json_ file to automate this process.

We'll also make use of the "rimraf" library to cleanup our output directory before building, in case we have files that no longer should remain from a previous build. We'll also make use of the "concurrently" library, which gives us a cross-platform way to run two or more cli commands in the background simultaneously. Lastly, we'll make use of the "nodemon" library, which is a great way to improve the developer experience, by automatically re-building our TypeScript files whenever a change is detected, so we don't have to re-run the scripts every time we make a change.

If they weren't installed before, install the following libraries:
`npm install rimraf concurrently nodemon`

Then, add the following to the "scripts" field in _package.json_:

```
"scripts": {
  "build": "rimraf dist && npx tsc",
  "prestart": "npm run build",
  "start": "node dist/server.js",
  "predev": "npm run build",
  "dev": "concurrently \"npx tsc -w\" \"nodemon ./dist/server.js\""
}
```

- **build** - This will empty our output directory, and then run the tsc command to build our TypeScript files and output them to that output directory
- **prestart** - Runs before "start".
- **start** - Builds our files, and then starts the server
  - This command is likely to be used to start in a real enviroment
- **predev** - Runs before "dev"
- **dev** - Builds our files in "watch-mode" and uses nodemon to run our server
  - This command is likely to be used in a development environment, and will detect changes and automatically rebuild for us

---

## Enhancing the Project

At this point, the project is ready-to-use, as implemented by the tutorial mentioned above.

However, in order to make it my own, I've made a few changes to the code, and I will continue to make changes as I find them necessary for future use-cases when building APIs.

### Re-organizing the directory structure

Create a `src` directory, and create the following elements:

- **app.ts** - Move this file into the _src_ folder
- **server.ts** - Create this file, which will make use of the "app" variable exported from the <u>app.ts</u> file, and define the "listen" function, where we start up our server.
  - Some of this functionality will be migrated from "app.ts" to "server.ts"
- **routes (directory)** - This is a folder within _src_ that will contain all of the different endpoint implementations, through the use of an Express Router.
  - The "GET / POST / PUT / DELETE" functions are defined and exported through these files, and are used in the <u>app.ts</u> file.

### Using an Environment (.env) file

In order to hide any variables we don't want directly exposed in our source code, we can make use of a `.env` file, and use the `dotenv` library to read its contents within our source code.

For our purposes, I've only moved the PORT variable into this file.

### Refactoring

#### app.ts

```
import express, { json, urlencoded } from "express";
import type { Express, Request, Response, NextFunction } from "express";
import createError, { HttpError } from "http-errors";

import indexRouter from "./routes/index";

const app: Express = express();

// Makes sure our API can only accept URL-encoded strings, or JSON data
app.use(json());
app.use(urlencoded({ extended: false }));

// Define our endpoints (routers) that are made available for our API
app.use("/", indexRouter);

// catch 404 and forward to error handler
app.use(function (req: Request, res: Response, next: NextFunction) {
  next(createError(404));
});

// error handler
app.use(function (
  err: HttpError,
  req: Request,
  res: Response,
  next: NextFunction
) {
  // set locals, only providing error in development
  res.locals.message = err.message;
  res.locals.error = req.app.get("env") === "development" ? err : {};

  // render the error page
  res.status(err.status || 500);
  res.json({ error: "error" });
});

export default app;
```

#### server-local.ts

```
import app from "./app";
import { createServer } from "http";
import { config } from "dotenv";

// Get port from environment and store in Express.
const myConfig = config();
if (myConfig?.parsed?.PORT) {
  process.env["PORT"] = myConfig.parsed.PORT;
}
const port = process.env.PORT || 3000;
app.set("port", port);

// Create HTTP server.
const server = createServer(app);

// Listen on provided port, on all network interfaces.
server.listen(port);
server.on("error", onError);
server.on("listening", onListening);

// Event listener for HTTP server "error" event.
function onError(error: any) {
  if (error.syscall !== "listen") {
    throw error;
  }

  const bind = typeof port === "string" ? "Pipe " + port : "Port " + port;

  // handle specific listen errors with friendly messages
  switch (error.code) {
    case "EACCES":
      console.error(bind + " requires elevated privileges");
      process.exit(1);
      break;
    case "EADDRINUSE":
      console.error(bind + " is already in use");
      process.exit(1);
      break;
    default:
      throw error;
  }
}

// Event listener for HTTP server "listening" event.
function onListening() {
  const addr = server.address();
  const bind = typeof addr === "string" ? "pipe " + addr : "port " + addr?.port;
  console.log(`Listening on ${bind}`);
}
```

#### index.ts

```
import express, { Router, Request, Response, NextFunction } from "express";

const router: Router = express.Router();

/* GET home page. */
// Returns a simple JSON object to the user when they navigate to the homepage
// of our server
router.get("/", function (req: Request, res: Response, next: NextFunction) {
  res.status(200).json({ msg: "Hello", age: 29 });
});

// This "router" object is referenced within "app.ts", and uses to expose the method
// on our API/server
export default router;
```

---

## Integrating Docker & AWS (Lambda / API Gateway / ECR)

I've wanted to be able to quickly generate an API that is publicly available, and the steps that I detail below describe exactly how I'm able to achieve that.

### Creating a new "server" file for hosing via Lambda

First, the `server.ts` file is renamed to `server-local.ts` and the package.json file has been updated to run that local server file when running the server locally.

This new file is created so that it can be referenced in the `Dockerfile` which is described in the next step. This file makes use of the `aws-serverless-express` library and wraps the Express app with the "serverless" functionality, so that it can function properly when handled through an AWS Lambda.

#### server-lambda.ts

```
const awsServerlessExpress = require("aws-serverless-express");
import app from "./app";

// Create HTTP server.
const server = awsServerlessExpress.createServer(app);

server.on("error", onError);
server.on("listening", onListening);

// Event listener for HTTP server "error" event.
function onError(error: any) {
  if (error.syscall !== "listen") {
    throw error;
  }

  // handle specific listen errors with friendly messages
  switch (error.code) {
    case "EACCES":
      console.error("requires elevated privileges");
      process.exit(1);
      break;
    case "EADDRINUSE":
      console.error("already in use");
      process.exit(1);
      break;
    default:
      throw error;
  }
}

// Event listener for HTTP server "listening" event.
function onListening() {
  const addr = server.address();
  const bind = typeof addr === "string" ? "pipe " + addr : "port " + addr?.port;
  console.log(`Listening on ${bind}`);
}

exports.handler = (event: any, context: any) => {
  awsServerlessExpress.proxy(server, event, context);
};
```

### Docker & ECR

In order to use our Express application via an AWS Lambda, we need to package our code into a Docker container, and then store that container into AWS ECR (Elastic Container Registry) so that we can reference the code from an AWS Lambda function.

This will mean that requests will be processed via Lambda functions, rather than an EC2 instance, which is a bit more cost effective, and can be helpful when scaling our application.

The provided `Dockerfile` will create the container necessary for uploading to ECR and using within a Lambda when calling the `docker build` command like so:

```
docker build -t <container-name> <path-to-dockerfile>
docker build -t docker-image .
```

Then, we can upload the container to ECR with the following commands:

```
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 387815262971.dkr.ecr.us-east-1.amazonaws.com

docker tag docker-image:test 387815262971.dkr.ecr.us-east-1.amazonaws.com/hello-world:latest

docker push 387815262971.dkr.ecr.us-east-1.amazonaws.com/hello-world:latest
```

Once the container is pushed to ECR, we can integrate into a Lambda and serve it via API Gateway.

For more steps on how to achieve this, view my tutorial here:

- [Deploy an API via Lambda & API Gateway](https://nblaisdell.atlassian.net/wiki/spaces/~701210f4b5f4c121e4cd5804ebc078dd6b379/pages/45383681/Deploy+an+API+on+Lambda+API+Gateway)
