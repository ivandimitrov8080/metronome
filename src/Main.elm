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
    }


type alias Subdivision =
    { name : String
    , groups : List Int
    }


type alias TimeSignature =
    { numerator : Int
    , denominator : Int
    }


type alias Model =
    { metronome : Metronome
    }


allSubdivisions : List Subdivision
allSubdivisions =
    [ { name = "Straight Quarters", groups = [ 1, 1, 1, 1 ] }
    , { name = "8th Subdivision", groups = [ 1, 1, 1, 1, 1, 1, 1, 1 ] }
    , { name = "Straight Quarters", groups = [ 1, 1, 1 ] }
    , { name = "8th Subdivision", groups = [ 2, 2, 2 ] }
    , { name = "2+2+3", groups = [ 2, 2, 3 ] }
    , { name = "3+2+2", groups = [ 3, 2, 2 ] }
    , { name = "2+3+2", groups = [ 2, 3, 2 ] }
    , { name = "2+3", groups = [ 2, 3 ] }
    , { name = "3+2", groups = [ 3, 2 ] }
    , { name = "Compound Meter (2x3)", groups = [ 3, 3 ] }
    , { name = "Straight Eighths", groups = [ 1, 1, 1, 1, 1, 1 ] }
    , { name = "Compound Meter (3x3)", groups = [ 3, 3, 3 ] }
    , { name = "3+2", groups = [ 3, 2 ] }
    , { name = "2+3", groups = [ 2, 3 ] }
    , { name = "Straight Quarters", groups = [ 1, 1, 1, 1, 1 ] }
    , { name = "Waltz Double (3+3)", groups = [ 3, 3 ] }
    , { name = "Straight Quarters", groups = [ 1, 1, 1, 1, 1, 1 ] }
    ]


allTimeSigs : List TimeSignature
allTimeSigs =
    [ { numerator = 4, denominator = 4 }
    , { numerator = 3, denominator = 4 }
    , { numerator = 7, denominator = 8 }
    , { numerator = 5, denominator = 8 }
    , { numerator = 6, denominator = 8 }
    , { numerator = 9, denominator = 8 }
    , { numerator = 5, denominator = 4 }
    , { numerator = 6, denominator = 4 }
    ]


init : () -> ( Model, Cmd Msg )
init _ =
    ( { metronome =
            { bpm = 120
            , timeSignature = { numerator = 4, denominator = 4 }
            , subdivision = { name = "Straight Quarters", groups = [ 1, 1, 1, 1 ] }
            , active = False
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
    { metronome | active = False }


beat : Cmd Msg
beat =
    beatClick "primary"


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
            ( model, beat )

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
            ]
        ]


viewBpmControl : Model -> Html Msg
viewBpmControl model =
    div [ style "display" "flex", style "align-items" "center", style "justify-content" "center" ]
        [ span [] [ text "BPM: " ]
        , inputSlider model.metronome.bpm
        ]


viewStartStop : Model -> Html Msg
viewStartStop model =
    div [ style "margin" "2em 0" ]
        [ if model.metronome.active then
            button [ onClick Start ]
                [ text
                    "Stop"
                ]

          else
            button [ onClick Stop ]
                [ text
                    "Start"
                ]
        ]


inputSlider : Float -> Html Msg
inputSlider bpmVal =
    Html.input
        [ Html.Attributes.type_ "range"
        , Html.Attributes.min "30"
        , Html.Attributes.max "240"
        , Html.Attributes.value (String.fromFloat bpmVal)
        , Html.Events.onInput (String.toFloat >> Maybe.withDefault bpmVal >> SetBpm)
        ]
        []


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }
