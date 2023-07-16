import request = require("supertest");
import app from "../src/app";

describe("The Main API", () => {
  it("should return a status 200 & a Message", () => {
    return request(app)
      .get("/")
      .expect(200)
      .expect("Content-Type", /json/)
      .then((response) => {
        console.log("body", response.body);
        expect(response.body).toEqual(
          expect.objectContaining({
            customMessage: expect.objectContaining({
              msg: "Hello",
            }),
          })
        );
      });
  });
});
