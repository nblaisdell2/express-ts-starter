import express, { Router } from "express";
import { helloWorld } from "../controllers/index";

const router: Router = express.Router();

/* GET home page. */
router.get("/", helloWorld);

export default router;
