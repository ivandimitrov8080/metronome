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
    , beatsPerMeasure : Int
    , currentBeat : Int
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { bpm = 120, running = False, flash = False, beatsPerMeasure = 4, currentBeat = 0 }
    , Cmd.none
    )



-- PORTS


port beatClick : String -> Cmd msg



-- MESSAGES


type Msg
    = IncrementBpm
    | DecrementBpm
    | SetBpm Int
    | StartStop
    | SetBeatsPerMeasure Int
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
                ( { model | running = False, flash = False, currentBeat = 0 }, Cmd.none )

            else
                ( { model | running = True, currentBeat = 0 }, Cmd.none )

        SetBpm bpmVal ->
            ( { model | bpm = bpmVal }, Cmd.none )

        SetBeatsPerMeasure n ->
            ( { model | beatsPerMeasure = n, currentBeat = 0 }, Cmd.none )

        Beat ->
            if model.running then
                let
                    nextBeat =
                        if model.currentBeat + 1 >= model.beatsPerMeasure then
                            0

                        else
                            model.currentBeat + 1

                    beatType =
                        if model.currentBeat == 0 then
                            "primary"

                        else
                            "sub"
                in
                ( { model | flash = True, currentBeat = nextBeat }
                , beatClick beatType
                )

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
    let
        dots =
            List.map
                (\i ->
                    span
                        [ style "display" "inline-block"
                        , style "margin" "0 .4em"
                        , style "width" "22px"
                        , style "height" "22px"
                        , style "border-radius" "50%"
                        , style "background"
                            (if i == model.currentBeat && model.flash then
                                "#2196f3"

                             else if i == 0 then
                                "#4caf50"

                             else
                                "#ddd"
                            )
                        , style "border"
                            (if i == 0 then
                                "2px solid #222"

                             else
                                "1px solid #bbb"
                            )
                        , style "transition" "background 0.1s"
                        ]
                        []
                )
                (List.range 0 (model.beatsPerMeasure - 1))

        bpmSlider =
            div []
                [ span [] [ text "BPM: " ]
                , inputSlider model.bpm
                , span [ style "margin-left" "10px" ] [ text (String.fromInt model.bpm) ]
                ]

        timeSigOptions =
            [ 2, 3, 4, 5, 6, 7, 8 ]

        timesigSelect =
            div [ style "margin" "1em 0" ]
                [ span [] [ text "Beats / Measure: " ]
                , Html.select
                    [ Html.Events.onInput (String.toInt >> Maybe.withDefault model.beatsPerMeasure >> SetBeatsPerMeasure) ]
                    (List.map
                        (\n -> Html.option [ Html.Attributes.value (String.fromInt n), Html.Attributes.selected (model.beatsPerMeasure == n) ] [ text (String.fromInt n) ])
                        timeSigOptions
                    )
                ]
    in
    div [ style "font-family" "sans-serif", style "text-align" "center", style "margin-top" "40px" ]
        [ bpmSlider
        , timesigSelect
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
        , div [ style "margin" "1.5em 0" ] dots
        ]


inputSlider : Int -> Html Msg
inputSlider bpmVal =
    Html.input
        [ Html.Attributes.type_ "range"
        , Html.Attributes.min "30"
        , Html.Attributes.max "240"
        , Html.Attributes.value (String.fromInt bpmVal)
        , Html.Events.onInput (String.toInt >> Maybe.withDefault bpmVal >> SetBpm)
        ]
        []



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
