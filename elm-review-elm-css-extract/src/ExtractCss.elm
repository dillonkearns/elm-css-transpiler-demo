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
import Elm.Writer
import List.Extra
import Maybe.Extra
import Murmur3
import Regex
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
    Rule.newProjectRuleSchema "ExtractCss" initialProjectContext
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
        |> Rule.withModuleDefinitionVisitor moduleDefinitionVisitor
        |> Rule.withExpressionVisitor expressionVisitor


expressionVisitor : Node Expression -> Rule.Direction -> ModuleContext -> ( List (Rule.Error {}), ModuleContext )
expressionVisitor node direction context =
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
        case ( node |> Node.value, direction ) of
            ( Expression.ListExpr [ singleAttrNodes ], Rule.OnEnter ) ->
                case extractStyleFixes singleAttrNodes of
                    Just ( hash, fixes, extractedStyles ) ->
                        let
                            cssAttrEndLocation : Elm.Syntax.Range.Location
                            cssAttrEndLocation =
                                Node.range singleAttrNodes |> .end
                        in
                        ( [ Rule.errorWithFix { message = "Add hashed class attr " ++ String.fromInt hash, details = [ String.fromInt hash ] }
                                (singleAttrNodes |> Node.range)
                                ((Review.Fix.insertAt cssAttrEndLocation <| ", Html.Styled.Attributes.class \"my-style" ++ String.fromInt hash ++ "\"")
                                    :: (fixes |> List.concat)
                                )
                          ]
                        , { context
                            | extractedStyles =
                                context.extractedStyles
                                    |> Dict.update hash
                                        (\maybeFound ->
                                            maybeFound
                                                |> Maybe.withDefault []
                                                |> List.append extractedStyles
                                                |> Just
                                        )
                          }
                        )

                    Nothing ->
                        ( [], context )

            _ ->
                ( [], context )


extractStyleFixes : Node Expression -> Maybe ( Int, List (List Review.Fix.Fix), List (Node Expression) )
extractStyleFixes node =
    case node |> Node.value of
        Expression.Application nodes ->
            case nodes |> List.map Node.value of
                [ Expression.FunctionOrValue [ "Html", "Styled", "Attributes" ] "css", Expression.ListExpr styleNodes ] ->
                    let
                        hash : Int
                        hash =
                            List.map expressionToString styleNodes
                                |> String.join ""
                                |> Murmur3.hashString 0

                        extractedStyles : List (Node Expression)
                        extractedStyles =
                            styleNodes
                                |> List.filterMap extractStyleNode
                    in
                    case extractedStyles of
                        [] ->
                            Nothing

                        _ ->
                            Just
                                ( hash
                                , [ styleNodes
                                        |> List.map
                                            (\styleNode ->
                                                Review.Fix.replaceRangeBy (Node.range styleNode)
                                                    "(Css.batch [])"
                                            )
                                  ]
                                , extractedStyles
                                )

                _ ->
                    Nothing

        _ ->
            Nothing


extractStyleNode : Node Expression -> Maybe (Node Expression)
extractStyleNode node =
    -- TODO filter down list (don't assume all are extractable)
    case node |> Node.value of
        Expression.ParenthesizedExpression paren ->
            extractStyleNode paren

        Expression.Application applied ->
            case List.map Node.value applied of
                [ Expression.FunctionOrValue [ "Css" ] "batch", Expression.ListExpr [] ] ->
                    Nothing

                _ ->
                    Just node

        _ ->
            Just node


expressionToString : Node Expression -> String
expressionToString style =
    style
        |> Elm.Writer.writeExpression
        |> Elm.Writer.write


type alias ProjectContext =
    { fixPlaceholderModuleKey : Maybe ( Rule.ModuleKey, Range )
    , extractedStyles : Dict Int (List (Node Expression))
    }


type alias ModuleContext =
    { range : Maybe Range
    , isSpecialModule : Bool
    , extractedStyles : Dict Int (List (Node Expression))
    }


initialProjectContext : ProjectContext
initialProjectContext =
    { fixPlaceholderModuleKey = Nothing
    , extractedStyles = Dict.empty
    }


fromProjectToModule : Rule.ModuleKey -> Node ModuleName -> ProjectContext -> ModuleContext
fromProjectToModule moduleKey moduleName projectContext =
    { range = Nothing
    , isSpecialModule = False
    , extractedStyles = Dict.empty
    }


fromModuleToProject : Rule.ModuleKey -> Node ModuleName -> ModuleContext -> ProjectContext
fromModuleToProject moduleKey moduleName moduleContext =
    { fixPlaceholderModuleKey =
        if Node.value moduleName == [ "StubCssGenerator" ] then
            moduleContext.range
                |> Maybe.map (Tuple.pair moduleKey)

        else
            Nothing
    , extractedStyles = moduleContext.extractedStyles
    }


foldProjectContexts : ProjectContext -> ProjectContext -> ProjectContext
foldProjectContexts newContext previousContext =
    { fixPlaceholderModuleKey =
        Maybe.Extra.or
            previousContext.fixPlaceholderModuleKey
            newContext.fixPlaceholderModuleKey
    , extractedStyles = mergeStyles newContext.extractedStyles previousContext.extractedStyles
    }


mergeStyles : Dict comparable appendable -> Dict comparable appendable -> Dict comparable appendable
mergeStyles =
    Dict.merge (\hash styles dict -> Dict.insert hash styles dict)
        (\hash styles1 styles2 dict ->
            Dict.insert hash
                (styles1 ++ styles2)
                dict
        )
        (\hash styles dict -> Dict.insert hash styles dict)
        Dict.empty


finalEvaluationForProject : ProjectContext -> List (Rule.Error { useErrorForModule : () })
finalEvaluationForProject projectContext =
    case projectContext.fixPlaceholderModuleKey of
        Just ( moduleKey, range ) ->
            case projectContext.extractedStyles |> Dict.toList of
                [] ->
                    []

                allStyles ->
                    [ Rule.errorForModuleWithFix moduleKey
                        { message = "TODO"
                        , details = [ "" ]
                        }
                        range
                        [ Review.Fix.replaceRangeBy range
                            ("\"import Css\\n\\nclasses = [ "
                                ++ (List.map
                                        extractedClassToString
                                        allStyles
                                        |> String.join ","
                                   )
                                ++ "]\"\n"
                            )
                        ]
                    ]

        _ ->
            []


extractedClassToString : ( Int, List (Node Expression) ) -> String
extractedClassToString ( hash, c ) =
    "( "
        ++ String.fromInt hash
        ++ " , [ "
        ++ (c
                |> List.Extra.uniqueBy expressionToString
                |> List.map (expressionToString >> escapeQuotes)
                |> String.join ", "
           )
        ++ " ] ) "


escapeQuotes : String -> String
escapeQuotes string =
    string
        |> String.replace "\"" "\\\""


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
