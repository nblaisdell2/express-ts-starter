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
