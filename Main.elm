port module Main exposing (main)

import Browser
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import Time



-- MODEL


type alias Model =
    { bpm : Int
    , running : Bool
    , flash : Bool
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { bpm = 120, running = False, flash = False }
    , Cmd.none
    )



-- PORTS


port beatClick : () -> Cmd msg



-- MESSAGES


type Msg
    = IncrementBpm
    | DecrementBpm
    | StartStop
    | Beat



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        IncrementBpm ->
            ( { model | bpm = model.bpm + 1 }, Cmd.none )

        DecrementBpm ->
            ( { model | bpm = max 20 (model.bpm - 1) }, Cmd.none )

        StartStop ->
            if model.running then
                ( { model | running = False, flash = False }, Cmd.none )

            else
                ( { model | running = True }, Cmd.none )

        Beat ->
            if model.running then
                ( { model | flash = True }, beatClick () )

            else
                ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.running then
        let
            interval =
                60000 // model.bpm
        in
        Time.every (toFloat interval) (\_ -> Beat)

    else
        Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    div [ style "font-family" "sans-serif", style "text-align" "center", style "margin-top" "40px" ]
        [ div []
            [ button [ onClick DecrementBpm ] [ text "-" ]
            , span [ style "font-size" "2em", style "margin" "0 1em" ] [ text (String.fromInt model.bpm ++ " BPM") ]
            , button [ onClick IncrementBpm ] [ text "+" ]
            ]
        , div [ style "margin" "2em 0" ]
            [ button [ onClick StartStop ]
                [ text
                    (if model.running then
                        "Stop"

                     else
                        "Start"
                    )
                ]
            ]
        , div
            [ style "height" "60px"
            , style "width" "60px"
            , style "margin" "2em auto"
            , style "border-radius" "50%"
            , style "background"
                (if model.flash then
                    "#4caf50"

                 else
                    "#ddd"
                )
            , style "transition" "background 0.1s"
            ]
            []
        ]



-- FLASH HANDLING


main =
    Browser.element
        { init = init
        , update = updateWithFlash
        , subscriptions = subscriptions
        , view = view
        }



-- Reset flash after rendering


updateWithFlash : Msg -> Model -> ( Model, Cmd Msg )
updateWithFlash msg model =
    let
        ( updatedModel, cmd ) =
            update msg model
    in
    if updatedModel.flash then
        ( { updatedModel | flash = False }, cmd )

    else
        ( updatedModel, cmd )
