port module Main exposing (main)

import Browser
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import Time


port beatClick : String -> Cmd msg


type alias Metronome =
    { bpm : Float
    , timeSignature : TimeSignature
    , subdivision : Subdivision
    , active : Bool
    , currentBeat : Int
    , remainder : Int
    , currentBar : Int
    }


type alias Subdivision =
    { name : String
    , groups : List Int
    }


type alias TimeSignature =
    ( Int, Int )


type alias Model =
    { metronome : Metronome
    }



-- allSubdivisions : List Subdivision
-- allSubdivisions =
--     [ { name = "Straight Quarters", groups = [ 1, 1, 1, 1 ] }
--     , { name = "8th Subdivision", groups = [ 1, 1, 1, 1, 1, 1, 1, 1 ] }
--     , { name = "Straight Quarters", groups = [ 1, 1, 1 ] }
--     , { name = "8th Subdivision", groups = [ 2, 2, 2 ] }
--     , { name = "2+2+3", groups = [ 2, 2, 3 ] }
--     , { name = "3+2+2", groups = [ 3, 2, 2 ] }
--     , { name = "2+3+2", groups = [ 2, 3, 2 ] }
--     , { name = "2+3", groups = [ 2, 3 ] }
--     , { name = "3+2", groups = [ 3, 2 ] }
--     , { name = "Compound Meter (2x3)", groups = [ 3, 3 ] }
--     , { name = "Straight Eighths", groups = [ 1, 1, 1, 1, 1, 1 ] }
--     , { name = "Compound Meter (3x3)", groups = [ 3, 3, 3 ] }
--     , { name = "3+2", groups = [ 3, 2 ] }
--     , { name = "2+3", groups = [ 2, 3 ] }
--     , { name = "Straight Quarters", groups = [ 1, 1, 1, 1, 1 ] }
--     , { name = "Waltz Double (3+3)", groups = [ 3, 3 ] }
--     , { name = "Straight Quarters", groups = [ 1, 1, 1, 1, 1, 1 ] }
--     ]


allTimeSignatures : List TimeSignature
allTimeSignatures =
    [ ( 4, 4 )
    , ( 3, 4 )
    , ( 7, 8 )
    , ( 5, 8 )
    , ( 6, 8 )
    , ( 9, 8 )
    , ( 5, 4 )
    , ( 6, 4 )
    ]


timeSignatureToString : TimeSignature -> String
timeSignatureToString ( num, den ) =
    String.fromInt num ++ "/" ++ String.fromInt den


stringToTimeSignature : String -> Maybe TimeSignature
stringToTimeSignature str =
    case String.split "/" str of
        [ numStr, denStr ] ->
            case ( String.toInt numStr, String.toInt denStr ) of
                ( Just num, Just den ) ->
                    Just ( num, den )

                _ ->
                    Nothing

        _ ->
            Nothing


init : () -> ( Model, Cmd Msg )
init _ =
    ( { metronome =
            { bpm = 120
            , timeSignature = ( 4, 4 )
            , subdivision = { name = "Straight Quarters", groups = [ 1, 1, 1, 1 ] }
            , active = False
            , currentBeat = 0
            , remainder = 0
            , currentBar = 0
            }
      }
    , Cmd.none
    )


type Msg
    = SetBpm Float
    | Start
    | Stop
    | SetTimeSignature TimeSignature
    | Beat


start : Metronome -> Metronome
start metronome =
    { metronome | active = True }


stop : Metronome -> Metronome
stop metronome =
    { metronome | active = False, currentBeat = 0, currentBar = 0 }


beat : Model -> ( Model, Cmd Msg )
beat model =
    let
        num : Int
        num =
            Tuple.first model.metronome.timeSignature

        remainder : Int
        remainder =
            remainderBy num model.metronome.currentBeat

        beatType : String
        beatType =
            if remainder == 0 then
                "primary"

            else
                ""

        metronome : Metronome
        metronome =
            model.metronome

        previousBeat : Int
        previousBeat =
            model.metronome.currentBeat

        newBar : Int
        newBar =
            if remainder == 0 then
                model.metronome.currentBar + 1

            else
                model.metronome.currentBar

        newMetronome : Metronome
        newMetronome =
            { metronome | currentBeat = previousBeat + 1, remainder = remainder, currentBar = newBar }
    in
    ( { model | metronome = newMetronome }, beatClick beatType )


setBpm : Metronome -> Float -> Metronome
setBpm metronome bpm =
    { metronome | bpm = bpm }


setTimeSignature : Metronome -> TimeSignature -> Metronome
setTimeSignature metronome timeSignature =
    { metronome | timeSignature = timeSignature }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Start ->
            ( { model | metronome = start model.metronome }, Cmd.none )

        Stop ->
            ( { model | metronome = stop model.metronome }, Cmd.none )

        Beat ->
            beat model

        SetBpm newBpm ->
            ( { model | metronome = setBpm model.metronome newBpm }, Cmd.none )

        SetTimeSignature timeSignature ->
            ( { model | metronome = setTimeSignature model.metronome timeSignature }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.metronome.active then
        let
            minute : Float
            minute =
                60 * 1000

            interval : Float
            interval =
                minute / model.metronome.bpm
        in
        Time.every interval (\_ -> Beat)

    else
        Sub.none



-- VIEW BEAT DOTS --


viewBeatDots : Model -> Html Msg
viewBeatDots model =
    let
        dots : List (Html Msg)
        dots =
            List.range 0 (Tuple.first model.metronome.timeSignature - 1)
                |> List.map
                    (\i ->
                        let
                            isCurrent : Bool
                            isCurrent =
                                model.metronome.remainder == i

                            color : String
                            color =
                                if isCurrent then
                                    if i == 0 then
                                        "yellow"

                                    else
                                        "blue"

                                else
                                    "#ccc"
                        in
                        span
                            [ style "display" "inline-block"
                            , style "width" "24px"
                            , style "height" "24px"
                            , style "border-radius" "50%"
                            , style "margin" "6px"
                            , style "background" color
                            , style "border" "2px solid #888"
                            ]
                            []
                    )
    in
    div [ style "display" "flex", style "justify-content" "center", style "margin" "32px 0" ] dots


view : Model -> Html Msg
view model =
    div
        [ style "font-family" "sans-serif"
        , style "display" "flex"
        , style "height" "100vh"
        , style "margin" "0"
        ]
        [ div [ style "flex-grow" "1", style "text-align" "center", style "margin-top" "40px" ]
            [ viewBpmControl model
            , viewStartStop model
            , viewBeatDots model
            ]
        ]


viewBpmControl : Model -> Html Msg
viewBpmControl model =
    div [ style "display" "flex", style "align-items" "center", style "justify-content" "center" ]
        [ span [] [ text ("BPM: " ++ String.fromFloat model.metronome.bpm) ]
        , Html.input
            [ Html.Attributes.type_ "range"
            , Html.Attributes.min "30"
            , Html.Attributes.max "240"
            , Html.Attributes.value (String.fromFloat model.metronome.bpm)
            , Html.Events.onInput (String.toFloat >> Maybe.withDefault model.metronome.bpm >> SetBpm)
            ]
            []
        , Html.select
            [ Html.Attributes.value (timeSignatureToString model.metronome.timeSignature)
            , Html.Events.onInput (stringToTimeSignature >> Maybe.withDefault model.metronome.timeSignature >> SetTimeSignature)
            ]
            (List.map
                (\ts ->
                    Html.option
                        [ Html.Attributes.value (timeSignatureToString ts)
                        ]
                        [ text (timeSignatureToString ts) ]
                )
                allTimeSignatures
            )
        ]


viewStartStop : Model -> Html Msg
viewStartStop model =
    div [ style "margin" "2em 0" ]
        [ if model.metronome.active then
            button [ onClick Stop ]
                [ text
                    "Stop"
                ]

          else
            button [ onClick Start ]
                [ text
                    "Start"
                ]
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }
