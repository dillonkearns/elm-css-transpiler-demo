#!/usr/bin/env node

const { compileToStringSync } = require("node-elm-compiler");
const fs = require("fs");

async function run() {
  (function () {
    const string = compileToStringSync(["./src/CssGenerator.elm"], {
      output: "tmp.js",
      cwd: process.cwd(),
    });

    eval(string.toString());
    const app = this.Elm.CssGenerator.init({ flags: {} });
    app.ports.sendFile.subscribe((fileBody) => {
      console.log("output", fileBody);
      fs.writeFileSync(
        "./src/Output.elm",
        `port module Output exposing (main)

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

run();
