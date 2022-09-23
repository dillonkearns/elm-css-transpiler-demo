# elm-review-elm-css-extract

Provides [`elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/) rules to REPLACEME.


## Provided rules

- [`ExtractCss`](https://package.elm-lang.org/packages/dillonkearns/elm-review-elm-css-extract/1.0.0/ExtractCss) - Reports REPLACEME.


## Configuration

```elm
module ReviewConfig exposing (config)

import ExtractCss
import Review.Rule exposing (Rule)

config : List Rule
config =
    [ ExtractCss.rule
    ]
```


## Try it out

You can try the example configuration above out by running the following command:

```bash
elm-review --template dillonkearns/elm-review-elm-css-extract/example
```
