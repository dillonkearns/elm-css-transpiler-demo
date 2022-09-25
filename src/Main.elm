module Main exposing (main)

import Browser
import Css
import Html as H exposing (Html)
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css)
import Html.Styled.Events exposing (onClick)


type alias Model =
    { count : Int }


initialModel : Model
initialModel =
    { count = 0 }


type Msg
    = Increment
    | Decrement


update : Msg -> Model -> Model
update msg model =
    case msg of
        Increment ->
            { model | count = model.count + 1 }

        Decrement ->
            { model | count = model.count - 1 }


view : Model -> H.Html Msg
view model =
    div
        [ Html.Styled.Attributes.css
            [ Css.backgroundColor (Css.hex "#ff375a")
            , Css.color (Css.hex "#ffffff")
            ]
        ]
        [ button [ onClick Increment ] [ text "+1" ]
        , div [] [ text <| String.fromInt model.count ]
        , button [ onClick Decrement ] [ text "-1" ]
        ]
        |> Html.Styled.toUnstyled


main : Program () Model Msg
main =
    Browser.sandbox
        { init = initialModel
        , view = view
        , update = update
        }
