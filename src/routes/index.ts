import express, { Router } from "express";
import { helloWorld } from "../controllers/index";

const router: Router = express.Router();

// Define the routes and methods available for each route
router.route("/").get(helloWorld);

export default router;
