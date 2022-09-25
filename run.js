#!/usr/bin/env node

const { compileToStringSync } = require("node-elm-compiler");
const fs = require("fs");
const spawnSync = require("cross-spawn").sync;

async function run() {
  const userElmJson = JSON.parse(fs.readFileSync("./elm.json"));
  fs.writeFileSync(
    "./.elm-css-transpiler/elm.json",
    JSON.stringify(rewriteElmJson(userElmJson))
  );

  process.chdir(".elm-css-transpiler");

  runElmReview();
  fs.writeFileSync("./src/CssGenerator.elm", cssGeneratorSrc());

  (function () {
    const string = compileToStringSync(["./src/CssGenerator.elm"], {
      output: "tmp.js",
      cwd: process.cwd(),
    });

    eval(string.toString());
    const app = this.Elm.CssGenerator.init({ flags: {} });
    app.ports.sendFile.subscribe((fileBody) => {
      fs.writeFileSync(
        "./src/Output.elm",
        `port module Output exposing (main)

import Css
import Css.Global
import Css.Preprocess
import Css.Preprocess.Resolve
import Murmur3
import Regex

${fileBody}

toCssFile : List (List Css.Style) -> String
toCssFile lists =
    lists
        |> List.map
            (\\styles ->
                let
                    ( hashedName, body ) =
                        styleToClassGroup styles
                in
                "."
                    ++ hashedName
                    ++ " {\\n"
                    ++ body
                    ++ "\\n}"
            )
        |> String.join "\\n\\n"


styleToClassGroup : List Css.Style -> ( String, String )
styleToClassGroup styles =
    let
        allAsString : String
        allAsString =
            styles |> List.map (\\style -> "    " ++ styleToString style) |> String.join "\\n"
    in
    ( "my-style" ++ (Murmur3.hashString 0 allAsString |> String.fromInt)
    , allAsString
    )


styleToString : Css.Style -> String
styleToString style =
    prettyPrint (Css.Preprocess.stylesheet [ Css.Global.p [ style ] ])
        |> Regex.replace (Regex.fromString "^\\\\w*p\\\\w*\\\\{" |> Maybe.withDefault Regex.never) (\\_ -> "")
        |> Regex.replace (Regex.fromString ";}" |> Maybe.withDefault Regex.never) (\\_ -> ";")


prettyPrint : Css.Preprocess.Stylesheet -> String
prettyPrint sheet =
    Css.Preprocess.Resolve.compile sheet


type alias Flags =
    ()


type Msg
    = NoOp


type alias Model =
    {}


main : Program Flags Model Msg
main =
    Platform.worker
        { init = init
        , update = \\_ model -> ( model, Cmd.none )
        , subscriptions = \\_ -> Sub.none
        }


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( {}, sendFile (toCssFile classes) )


port sendFile : String -> Cmd msg
`
      );
    });
  })();

  setTimeout(function () {
    const string = compileToStringSync(["./src/Output.elm"], {
      output: "tmp2.js",
      cwd: process.cwd(),
    });

    eval(string.toString());
    const app = this.Elm.Output.init({ flags: {} });

    app.ports.sendFile.subscribe((fileBody) => {
      fs.writeFileSync("./styles.css", fileBody);
    });
  }, 100);
}

function runElmReview() {
  const output = spawnSync(
    "elm-review",
    [
      "--config",
      "../elm-review-elm-css-extract/preview/",
      "--fix-all-without-prompt",
      "--debug",
    ],
    {
      env: process.env,
      shell: true,
      stdio: "inherit",
    }
  );
  if (output.status === 0) {
  } else {
    console.log("elm-review error");
    console.log(output.output.toString());
    process.exit(1);
  }
}

function rewriteElmJson(elmJson) {
  // Since we're copying the user's `src/` directory,
  // we leave that part of the elm.json unmodified
  elmJson["source-directories"] = elmJson["source-directories"].filter(
    (item) => {
      return item != "src";
    }
  );
  // prepend ../ to remaining entries since we created a folder one level up from the user's project
  elmJson["source-directories"] = elmJson["source-directories"].map((item) => {
    return "../" + item;
  });
  elmJson["source-directories"].push("src/");

  return elmJson;
}

run();

function cssGeneratorSrc() {
  return /* elm */ `port module CssGenerator exposing (main)

import StubCssGenerator


type alias Flags =
    ()


type Msg
    = NoOp


type alias Model =
    {}


main : Program Flags Model Msg
main =
    Platform.worker
        { init = init
        , update = \\_ model -> ( model, Cmd.none )
        , subscriptions = \\_ -> Sub.none
        }


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( {}, sendFile (StubCssGenerator.generatedCssListHere____THIS_IS_MY_SPECIAL_CODE) )


port sendFile : String -> Cmd msg
  `;
}
