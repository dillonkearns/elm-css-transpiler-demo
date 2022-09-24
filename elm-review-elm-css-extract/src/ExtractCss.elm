module ExtractCss exposing (rule)

{-|

@docs rule

-}

import Dict exposing (Dict)
import Elm.Syntax.Expression as Expression exposing (Expression)
import Elm.Syntax.Import exposing (Import)
import Elm.Syntax.Module as Module exposing (Module)
import Elm.Syntax.ModuleName exposing (ModuleName)
import Elm.Syntax.Node as Node exposing (Node)
import Elm.Syntax.Range exposing (Range)
import Maybe.Extra
import Review.Fix
import Review.Rule as Rule exposing (Rule)
import Set exposing (Set)


{-| Reports... REPLACEME

    config =
        [ ExtractCss.rule
        ]


## Fail

    a =
        "REPLACEME example to replace"


## Success

    a =
        "REPLACEME example to replace"


## When (not) to enable this rule

This rule is useful when REPLACEME.
This rule is not useful when REPLACEME.


## Try it out

You can try this rule out by running the following command:

```bash
elm-review --template dillonkearns/elm-review-elm-css-extract/example --rules ExtractCss
```

-}
rule : Rule
rule =
    Rule.newProjectRuleSchema "NoUnusedExportedFunctions" initialProjectContext
        -- Omitted, but this will collect the list of exposed modules for packages.
        -- We don't want to report functions that are exposed
        |> Rule.withModuleVisitor moduleVisitor
        |> Rule.withModuleContext
            { fromProjectToModule = fromProjectToModule
            , fromModuleToProject = fromModuleToProject
            , foldProjectContexts = foldProjectContexts
            }
        |> Rule.withFinalProjectEvaluation finalEvaluationForProject
        |> Rule.fromProjectRuleSchema


moduleVisitor :
    Rule.ModuleRuleSchema {} ModuleContext
    -> Rule.ModuleRuleSchema { hasAtLeastOneVisitor : () } ModuleContext
moduleVisitor schema =
    schema
        -- Omitted, but this will collect uses of exported functions
        |> Rule.withModuleDefinitionVisitor moduleDefinitionVisitor
        |> Rule.withExpressionVisitor expressionVisitor


expressionVisitor : Node Expression -> Rule.Direction -> ModuleContext -> ( List (Rule.Error {}), ModuleContext )
expressionVisitor node direction context =
    --case context of
    --    DebugLogWasNotImported ->
    --        ( [], context )
    --
    --    DebugLogWasImported ->
    --        case ( direction, Node.value node ) of
    --            ( Rule.OnEnter, Expression.FunctionOrValue [] "log" ) ->
    --                ( [ Rule.error
    --                        { message = "Remove the use of `Debug` before shipping to production"
    --                        , details = [ "The `Debug` module is useful when developing, but is not meant to be shipped to production or published in a package. I suggest removing its use before committing and attempting to push to production." ]
    --                        }
    --                        (Node.range node)
    --                  ]
    --                , context
    --                )
    --
    --            _ ->
    if context.isSpecialModule then
        case node |> Node.value of
            Expression.Literal literalString ->
                if literalString == "" then
                    ( [], { context | range = Just (Node.range node) } )

                else
                    ( [], context )

            _ ->
                ( [], context )

    else
        ( [], context )


type alias ProjectContext =
    { -- Modules exposed by the package, that we should not report
      fixPlaceholderModuleKey : Maybe ( Rule.ModuleKey, Range )
    }


type alias ModuleContext =
    { --isExposed : Bool
      --, exposed : Dict String Range
      --, used : Set ( ModuleName, String )
      range : Maybe Range
    , isSpecialModule : Bool
    }


initialProjectContext : ProjectContext
initialProjectContext =
    { fixPlaceholderModuleKey = Nothing }


fromProjectToModule : Rule.ModuleKey -> Node ModuleName -> ProjectContext -> ModuleContext
fromProjectToModule moduleKey moduleName projectContext =
    --{ isExposed = Set.member (Node.value moduleName) projectContext.exposedModules
    --, exposed = Dict.empty
    --, used = Set.empty
    --}
    { range = Nothing
    , isSpecialModule = False
    }


fromModuleToProject : Rule.ModuleKey -> Node ModuleName -> ModuleContext -> ProjectContext
fromModuleToProject moduleKey moduleName moduleContext =
    { ---- We don't care about this value, we'll take
      --  -- the one from the initial context when folding
      --  exposedModules = Set.empty
      --, exposedFunctions =
      --    if moduleContext.isExposed then
      --        -- If the module is exposed, don't collect the exported functions
      --        Dict.empty
      --
      --    else
      --        -- Create a dictionary with all the exposed functions, associated to
      --        -- the module that was just visited
      --        Dict.singleton
      --            (Node.value moduleName)
      --            { moduleKey = moduleKey
      --            , exposed = moduleContext.exposed
      --            }
      --, used = moduleContext.used
      fixPlaceholderModuleKey =
        if Node.value moduleName == [ "StubCssGenerator" ] then
            moduleContext.range
                |> Maybe.map (Tuple.pair moduleKey)

        else
            Nothing
    }


foldProjectContexts : ProjectContext -> ProjectContext -> ProjectContext
foldProjectContexts newContext previousContext =
    { -- Always take the one from the "initial" context,
      -- which is always the second argument
      --  exposedModules = previousContext.exposedModules
      --
      ---- Collect the exposed functions from the new context and the previous one.
      ---- We could use `Dict.merge`, but in this case, that doesn't change anything
      --, exposedFunctions = Dict.union previousContext.modules newContext.modules
      --
      ---- Collect the used functions from the new context and the previous one
      --, used = Set.union newContext.used previousContext.used
      fixPlaceholderModuleKey =
        Maybe.Extra.or
            previousContext.fixPlaceholderModuleKey
            newContext.fixPlaceholderModuleKey
    }


finalEvaluationForProject : ProjectContext -> List (Rule.Error { useErrorForModule : () })
finalEvaluationForProject projectContext =
    -- Implementation of `unusedFunctions` omitted, but it returns the list
    -- of unused functions, along with the associated module key and range
    case projectContext.fixPlaceholderModuleKey of
        Just ( moduleKey, range ) ->
            --Rule.errorForModule moduleKey
            --    { message = "TODO"
            --    , details = [ "" ]
            --    }
            --    (Debug.todo "range")
            [ Rule.errorForModuleWithFix moduleKey
                { message = "TODO"
                , details = [ "" ]
                }
                range
                [ Review.Fix.replaceRangeBy range """"import Css\\n\\nclasses = [ [ Css.backgroundColor (Css.hex "#ff375a"), Css.color (Css.hex "#ffffff") ] ]"
"""
                ]
            ]

        _ ->
            []


moduleDefinitionVisitor : Node Module -> ModuleContext -> ( List (Rule.Error {}), ModuleContext )
moduleDefinitionVisitor node context =
    if (Node.value node |> Module.moduleName) == [ "StubCssGenerator" ] then
        ( []
        , { context
            | isSpecialModule = True
          }
        )

    else
        ( [], context )
