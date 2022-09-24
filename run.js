#!/usr/bin/env node

const { compileToStringSync } = require("node-elm-compiler");
const fs = require("fs");

async function run() {
  const string = compileToStringSync(["./src/CssGenerator.elm"], {
    output: "tmp.js",
    cwd: process.cwd(),
  });
  
  eval(string.toString());
  const app = this.Elm.CssGenerator.init({ flags: {} });
  app.ports.sendFile.subscribe((fileBody) => {
    console.log("output", fileBody);
    fs.writeFileSync("./src/Output.elm", fileBody);
  });
}

run();
