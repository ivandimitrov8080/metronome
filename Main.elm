port module Main exposing (main)

import Basics exposing (clamp)
import Browser
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import Process
import Task
import Time



-- MODEL


type alias Model =
    { bpm : Int
    , bpmInput : String
    , running : Bool
    , flash : Bool
    , tsNum : Int -- numerator (beats per measure)
    , tsDen : Int -- denominator (note value that gets the beat)
    , currentBeat : Int
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { bpm = 120, bpmInput = "120", running = False, flash = False, tsNum = 4, tsDen = 4, currentBeat = 0 }
    , Cmd.none
    )



-- PORTS


port beatClick : String -> Cmd msg



-- MESSAGES


type Msg
    = IncrementBpm
    | DecrementBpm
    | SetBpm Int
    | SetBpmInput String
    | SetBpmFromInput
    | StartStop
    | SetTimeSig Int Int
    | Beat
    | AdvanceBeat



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        IncrementBpm ->
            let
                newBpm =
                    model.bpm + 1
            in
            ( { model | bpm = newBpm, bpmInput = String.fromInt newBpm }, Cmd.none )

        DecrementBpm ->
            let
                newBpm =
                    max 20 (model.bpm - 1)
            in
            ( { model | bpm = newBpm, bpmInput = String.fromInt newBpm }, Cmd.none )

        StartStop ->
            if model.running then
                ( { model | running = False, flash = False, currentBeat = 0 }, Cmd.none )

            else
                ( { model | running = True, currentBeat = -1 }, Cmd.none )

        SetBpm bpmVal ->
            ( { model | bpm = bpmVal, bpmInput = String.fromInt bpmVal }, Cmd.none )

        SetBpmInput str ->
            ( { model | bpmInput = str }, Cmd.none )

        SetBpmFromInput ->
            case String.toInt model.bpmInput of
                Just v ->
                    let
                        clamped =
                            clamp 30 240 v
                    in
                    ( { model | bpm = clamped, bpmInput = String.fromInt clamped }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        SetTimeSig newNum newDen ->
            ( { model | tsNum = newNum, tsDen = newDen, currentBeat = 0 }, Cmd.none )

        Beat ->
            if model.running then
                let
                    nextBeat =
                        if model.currentBeat + 1 >= model.tsNum then
                            0

                        else
                            model.currentBeat + 1

                    beatType =
                        if nextBeat == 0 then
                            "primary"

                        else
                            "sub"
                in
                ( { model | flash = True, currentBeat = nextBeat }
                , beatClick beatType
                )

            else
                ( model, Cmd.none )

        AdvanceBeat ->
            ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.running then
        let
            interval =
                60000 / toFloat model.bpm * (4 / toFloat model.tsDen)
        in
        Time.every interval (\_ -> Beat)

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
                            (if i == model.currentBeat then
                                if i == 0 then
                                    "#4caf50"

                                else
                                    "#2196f3"

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
                (List.range 0 (model.tsNum - 1))

        bpmSlider =
            div [ style "display" "flex", style "align-items" "center", style "justify-content" "center" ]
                [ span [] [ text "BPM: " ]
                , inputSlider model.bpm
                , inputBpmBox model
                ]

        timeSigList =
            [ ( 2, 4 )
            , ( 3, 4 )
            , ( 4, 4 )
            , ( 5, 4 )
            , ( 6, 4 )
            , ( 7, 4 )
            , ( 3, 8 )
            , ( 5, 8 )
            , ( 6, 8 )
            , ( 7, 8 )
            , ( 9, 8 )
            , ( 11, 8 )
            , ( 12, 8 )
            , ( 5, 16 )
            , ( 6, 16 )
            , ( 7, 16 )
            , ( 9, 16 )
            , ( 12, 16 )
            ]

        timesigSelect =
            div [ style "margin" "1em 0" ]
                [ span [] [ text "Time Signature: " ]
                , Html.select
                    [ Html.Events.onInput
                        (\str ->
                            case String.split "/" str of
                                [ numStr, denStr ] ->
                                    case ( String.toInt numStr, String.toInt denStr ) of
                                        ( Just num, Just den ) ->
                                            SetTimeSig num den

                                        _ ->
                                            SetTimeSig model.tsNum model.tsDen

                                _ ->
                                    SetTimeSig model.tsNum model.tsDen
                        )
                    ]
                    (List.map
                        (\( num, den ) ->
                            let
                                shown =
                                    String.fromInt num ++ "/" ++ String.fromInt den
                            in
                            Html.option
                                [ Html.Attributes.value shown
                                , Html.Attributes.selected (model.tsNum == num && model.tsDen == den)
                                ]
                                [ text shown ]
                        )
                        timeSigList
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


inputBpmBox : Model -> Html Msg
inputBpmBox model =
    Html.input
        [ Html.Attributes.type_ "number"
        , Html.Attributes.min "30"
        , Html.Attributes.max "240"
        , Html.Attributes.value model.bpmInput
        , Html.Attributes.style "width" "60px"
        , Html.Attributes.style "margin-left" "10px"
        , Html.Events.onInput SetBpmInput
        , Html.Events.onBlur SetBpmFromInput
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
