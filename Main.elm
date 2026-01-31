port module Main exposing (main)

import Basics exposing (clamp)
import Browser
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import List.Extra
import Process
import Task
import Time



-- MODEL


type alias Subdivision =
    { name : String
    , groups : List Int
    }


type alias TimeSigOptions =
    { numerator : Int
    , denominator : Int
    , subdivisions : List Subdivision
    }


allTimeSigs : List TimeSigOptions
allTimeSigs =
    [ { numerator = 4
      , denominator = 4
      , subdivisions =
            [ { name = "Straight Quarters", groups = [ 1, 1, 1, 1 ] }
            , { name = "8th Subdivision", groups = [ 2, 2, 2, 2 ] }
            ]
      }
    , { numerator = 3
      , denominator = 4
      , subdivisions =
            [ { name = "Straight Quarters", groups = [ 1, 1, 1 ] }
            , { name = "8th Subdivision", groups = [ 2, 2, 2 ] }
            ]
      }
    , { numerator = 7
      , denominator = 8
      , subdivisions =
            [ { name = "2+2+3", groups = [ 2, 2, 3 ] }
            , { name = "3+2+2", groups = [ 3, 2, 2 ] }
            , { name = "2+3+2", groups = [ 2, 3, 2 ] }
            ]
      }
    , { numerator = 5
      , denominator = 8
      , subdivisions =
            [ { name = "2+3", groups = [ 2, 3 ] }
            , { name = "3+2", groups = [ 3, 2 ] }
            ]
      }
    , { numerator = 6
      , denominator = 8
      , subdivisions =
            [ { name = "Compound Meter (2x3)", groups = [ 3, 3 ] }
            , { name = "Straight Eighths", groups = [ 1, 1, 1, 1, 1, 1 ] }
            ]
      }
    , { numerator = 9
      , denominator = 8
      , subdivisions =
            [ { name = "Compound Meter (3x3)", groups = [ 3, 3, 3 ] }
            ]
      }
    , { numerator = 5
      , denominator = 4
      , subdivisions =
            [ { name = "3+2", groups = [ 3, 2 ] }
            , { name = "2+3", groups = [ 2, 3 ] }
            , { name = "Straight Quarters", groups = [ 1, 1, 1, 1, 1 ] }
            ]
      }
    , { numerator = 6
      , denominator = 4
      , subdivisions =
            [ { name = "Waltz Double (3+3)", groups = [ 3, 3 ] }
            , { name = "Straight Quarters", groups = [ 1, 1, 1, 1, 1, 1 ] }
            ]
      }

    -- Add more as needed
    ]


type alias Model =
    { bpm : Int
    , bpmInput : String
    , running : Bool
    , flash : Bool
    , tsNum : Int -- numerator (beats per measure)
    , tsDen : Int -- denominator (note value that gets the beat)
    , currentBeat : Int
    , subdivisionIdx : Int -- index of subdivision for current signature
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { bpm = 120
      , bpmInput = "120"
      , running = False
      , flash = False
      , tsNum = 4
      , tsDen = 4
      , currentBeat = 0
      , subdivisionIdx = 0 -- default to first option
      }
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
    | SetSubdivisionIdx Int
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
            -- Reset subdivisionIdx to 0 by default for new signature
            ( { model | tsNum = newNum, tsDen = newDen, currentBeat = 0, subdivisionIdx = 0 }, Cmd.none )

        SetSubdivisionIdx idx ->
            ( { model | subdivisionIdx = idx }, Cmd.none )

        Beat ->
            if model.running then
                let
                    -- get totalBeats, currentSub, groupBoundaries
                    currentSubOptions =
                        List.filter (\ts -> ts.numerator == model.tsNum && ts.denominator == model.tsDen) allTimeSigs

                    currentSubdivision =
                        case currentSubOptions of
                            t :: _ ->
                                let
                                    idx =
                                        if model.subdivisionIdx < List.length t.subdivisions then
                                            model.subdivisionIdx

                                        else
                                            0
                                in
                                List.Extra.getAt idx t.subdivisions

                            _ ->
                                Nothing

                    groupLengths =
                        case currentSubdivision of
                            Just sub ->
                                List.concatMap (\n -> List.repeat n ()) sub.groups

                            Nothing ->
                                List.repeat model.tsNum ()

                    totalBeats =
                        List.length groupLengths

                    groupBoundaries =
                        case currentSubdivision of
                            Just sub ->
                                let
                                    boundaries =
                                        List.foldl (\n ( acc, idx ) -> ( idx :: acc, idx + n )) ( [], 0 ) sub.groups |> Tuple.first |> List.reverse
                                in
                                boundaries

                            Nothing ->
                                [ 0 ]

                    nextBeat =
                        if model.currentBeat + 1 >= totalBeats then
                            0

                        else
                            model.currentBeat + 1

                    -- Get if current is group boundary (primary)
                    beatType =
                        if List.member nextBeat groupBoundaries then
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
        -- Get subdivision for the current signature
        currentSubOptions =
            List.filter (\ts -> ts.numerator == model.tsNum && ts.denominator == model.tsDen) allTimeSigs

        currentSubdivision =
            case currentSubOptions of
                t :: _ ->
                    let
                        idx =
                            if model.subdivisionIdx < List.length t.subdivisions then
                                model.subdivisionIdx

                            else
                                0
                    in
                    List.Extra.getAt idx t.subdivisions

                _ ->
                    Nothing

        -- Flatten out the groups
        groupLengths =
            case currentSubdivision of
                Just sub ->
                    List.concatMap (\n -> List.repeat n ()) sub.groups

                Nothing ->
                    List.repeat model.tsNum ()

        totalBeats =
            List.length groupLengths

        -- Get group boundaries for primary beats
        groupBoundaries =
            case currentSubdivision of
                Just sub ->
                    let
                        boundaries =
                            List.foldl (\n ( acc, idx ) -> ( idx :: acc, idx + n )) ( [], 0 ) sub.groups |> Tuple.first |> List.reverse
                    in
                    boundaries

                Nothing ->
                    [ 0 ]

        dots =
            List.map
                (\i ->
                    let
                        isPrimary =
                            List.member i groupBoundaries

                        isCurrent =
                            i == model.currentBeat

                        bgColor =
                            if isCurrent then
                                if isPrimary then
                                    "#4caf50"

                                else
                                    "#2196f3"

                            else if isPrimary then
                                "#bbb"

                            else
                                "#ddd"

                        borderColor =
                            if isPrimary then
                                "2px solid #222"

                            else
                                "1px solid #bbb"
                    in
                    span
                        [ style "display" "inline-block"
                        , style "margin" "0 .4em"
                        , style "width" "22px"
                        , style "height" "22px"
                        , style "border-radius" "50%"
                        , style "background" bgColor
                        , style "border" borderColor
                        , style "transition" "background 0.1s"
                        ]
                        []
                )
                (List.range 0 (totalBeats - 1))

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
        , -- Subdivision selector UI
          let
            subOptions =
                case currentSubOptions of
                    t :: _ ->
                        List.indexedMap Tuple.pair t.subdivisions

                    _ ->
                        []
          in
          if List.length subOptions > 1 then
            div [ style "margin" "1em 0" ]
                ([ span [] [ text "Subdivision: " ] ]
                    ++ List.map
                        (\( idx, sub ) ->
                            button
                                [ onClick (SetSubdivisionIdx idx)
                                , style "margin" "0 .5em"
                                , style "padding" "0.2em 0.7em"
                                , style "background"
                                    (if idx == model.subdivisionIdx then
                                        "#eee"

                                     else
                                        "#fff"
                                    )
                                , style "border" "1px solid #666"
                                , style "border-radius" "6px"
                                ]
                                [ text sub.name ]
                        )
                        subOptions
                )

          else
            text ""
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
