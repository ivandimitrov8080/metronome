port module Main exposing (main)

{-|


# Metronome Main Module

This module implements a customizable metronome app, supporting various time signatures, subdivisions, and BPM controls.

-}

import Basics exposing (clamp)
import Browser
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import List.Extra
import Process
import Task
import Time


port beatClick : String -> Cmd msg



-- TYPES


type alias BarConfig =
    { barNum : Int
    , bpm : Int
    }


type alias Subdivision =
    { name : String
    , groups : List Int
    }


type alias TimeSigOptions =
    { numerator : Int
    , denominator : Int
    , subdivisions : List Subdivision
    }


type alias Model =
    { bpm : Int
    , bpmInput : String
    , running : Bool
    , flash : Bool
    , tsNum : Int -- numerator (beats per measure)
    , tsDen : Int -- denominator (note value that gets the beat)
    , currentBeat : Int
    , subTick : Int -- for tracking sub-beats (for subdivisions between main beats)
    , showHighlight : Bool -- true=highlight dot, false=show all dots neutral
    , subdivisionIdx : Int -- index of subdivision for current signature
    , barConfigs : List BarConfig -- list of bpm change points, always sorted, unique barNum, always bar 1
    , activeBarNum : Int -- current bar (number, not index)
    , sidebarError : Maybe String -- error message for sidebar barNum input
    }



-- CONSTANTS


allTimeSigs : List TimeSigOptions
allTimeSigs =
    [ { numerator = 4
      , denominator = 4
      , subdivisions =
            [ { name = "Straight Quarters", groups = [ 1, 1, 1, 1 ] }
            , { name = "8th Subdivision", groups = [ 1, 1, 1, 1, 1, 1, 1, 1 ] }
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



-- INITIAL MODEL


init : () -> ( Model, Cmd Msg )
init _ =
    ( { bpm = 120
      , bpmInput = "120"
      , running = False
      , flash = False
      , tsNum = 4
      , tsDen = 4
      , currentBeat = 0 -- (this is subdivision beat, not bar#)
      , subTick = 0
      , showHighlight = True
      , subdivisionIdx = 0 -- default to first option
      , barConfigs = [ { barNum = 1, bpm = 120 } ]
      , activeBarNum = 1 -- (current bar, default for app is bar #1)
      , sidebarError = Nothing
      }
    , Cmd.none
    )



-- MESSAGES (Update actions)


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
      -- Sidebar/bar-list management:
    | SetBarBpm Int Int -- (barIdx, bpm)
    | SetBarNumber Int Int -- (barIdx, newBarNum)
    | AddBar
    | RemoveBar Int -- barIdx
    | SetActiveBar Int -- barIdx



-- UPDATE


{-|

    Handles all state updates and side-effects according to the received Msg.
    Pattern logs ensure correctness and exhaustive consideration of all update scenarios.

-}
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
                let
                    firstBar =
                        case List.minimum (List.map .barNum model.barConfigs) of
                            Just b ->
                                b

                            Nothing ->
                                1
                in
                ( { model | running = True, currentBeat = -1, activeBarNum = firstBar, bpm = bpmForBar firstBar model.barConfigs, bpmInput = String.fromInt (bpmForBar firstBar model.barConfigs) }, Cmd.none )

        SetTimeSig newNum newDen ->
            -- Reset subdivisionIdx to 0 by default for new signature
            ( { model | tsNum = newNum, tsDen = newDen, currentBeat = 0, subdivisionIdx = 0 }, Cmd.none )

        SetSubdivisionIdx idx ->
            ( { model | subdivisionIdx = idx }, Cmd.none )

        SetBarBpm idx newBpm ->
            let
                -- update only the bpm for the specified change point
                barConfigsUpd =
                    List.indexedMap
                        (\i bar ->
                            if i == idx then
                                { bar | bpm = newBpm }

                            else
                                bar
                        )
                        model.barConfigs
                        |> List.sortBy .barNum

                bpmNow =
                    bpmForBar model.activeBarNum barConfigsUpd

                newBpmInput =
                    String.fromInt bpmNow
            in
            ( { model | barConfigs = barConfigsUpd, bpm = bpmNow, bpmInput = newBpmInput }, Cmd.none )

        SetBarNumber idx newNum ->
            let
                orig =
                    List.Extra.getAt idx model.barConfigs

                currentBarNum =
                    case orig of
                        Just b ->
                            b.barNum

                        _ ->
                            1

                -- Don't allow duplicate barNum except this row
                alreadyExists =
                    List.indexedMap Tuple.pair model.barConfigs |> List.any (\( i, b ) -> i /= idx && b.barNum == newNum)

                isBar1 =
                    currentBarNum == 1
            in
            if (isBar1 && newNum /= 1) || (not isBar1 && newNum == 1) || alreadyExists || newNum < 1 then
                let
                    errMsg =
                        if newNum < 1 then
                            Just "Bar number must be at least 1."

                        else if alreadyExists then
                            Just ("A change point for bar " ++ String.fromInt newNum ++ " already exists.")

                        else if isBar1 && newNum /= 1 then
                            Just "Bar 1 cannot be changed."

                        else if not isBar1 && newNum == 1 then
                            Just "Bar 1 cannot be overwritten."

                        else
                            Just "Invalid bar number."
                in
                ( { model | sidebarError = errMsg }, Cmd.none )

            else if newNum == currentBarNum then
                ( { model | sidebarError = Nothing }, Cmd.none )

            else
                let
                    updatedBars =
                        List.indexedMap
                            (\i bar ->
                                if i == idx then
                                    { bar | barNum = newNum }

                                else
                                    bar
                            )
                            model.barConfigs
                            |> List.sortBy .barNum
                in
                ( { model | barConfigs = updatedBars, sidebarError = Nothing }, Cmd.none )

        AddBar ->
            let
                lastBarNum =
                    List.maximum (List.map .barNum model.barConfigs) |> Maybe.withDefault 1

                newBarNum =
                    lastBarNum + 1

                lastBpm =
                    bpmForBar lastBarNum model.barConfigs

                updatedBars =
                    (model.barConfigs ++ [ { barNum = newBarNum, bpm = lastBpm } ])
                        |> List.sortBy .barNum

                -- After adding, make the newly added one the selected sidebar row.
            in
            ( { model | barConfigs = updatedBars, activeBarNum = newBarNum, bpm = lastBpm, bpmInput = String.fromInt lastBpm }, Cmd.none )

        RemoveBar idx ->
            let
                barToRemove =
                    List.Extra.getAt idx model.barConfigs

                safeToRemove =
                    case barToRemove of
                        Just b ->
                            b.barNum /= 1

                        _ ->
                            False

                kept =
                    if safeToRemove then
                        List.Extra.indexedFoldl
                            (\i bar acc ->
                                if i == idx then
                                    acc

                                else
                                    bar :: acc
                            )
                            []
                            model.barConfigs
                            |> List.reverse

                    else
                        model.barConfigs

                sorted =
                    List.sortBy .barNum kept

                -- Determine correct new activeBarNum.
                newActiveBarNum =
                    if safeToRemove && model.activeBarNum == (barToRemove |> Maybe.map .barNum |> Maybe.withDefault 1) then
                        if List.length sorted > 0 then
                            List.head sorted |> Maybe.map .barNum |> Maybe.withDefault 1

                        else
                            1

                    else
                        model.activeBarNum

                newBpm =
                    bpmForBar newActiveBarNum sorted

                newBpmInput =
                    String.fromInt newBpm
            in
            ( { model | barConfigs = sorted, activeBarNum = newActiveBarNum, bpm = newBpm, bpmInput = newBpmInput }, Cmd.none )

        SetActiveBar barNum ->
            let
                newBpm =
                    bpmForBar barNum model.barConfigs

                newBpmStr =
                    String.fromInt newBpm
            in
            ( { model | activeBarNum = barNum, bpm = newBpm, bpmInput = newBpmStr }, Cmd.none )

        Beat ->
            let
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

                isEightSub =
                    case currentSubdivision of
                        Just sub ->
                            model.tsNum == 4 && model.tsDen == 4 && sub.name == "8th Subdivision"

                        Nothing ->
                            False

                totalBeats =
                    case currentSubdivision of
                        Just sub ->
                            if isEightSub then
                                4

                            else
                                List.sum sub.groups

                        Nothing ->
                            model.tsNum

                nextBeat =
                    if model.currentBeat + 1 >= totalBeats then
                        0

                    else
                        model.currentBeat + 1

                nextSubTick =
                    if isEightSub then
                        modBy 2 (model.subTick + 1)

                    else
                        0

                primaryHit =
                    not isEightSub || model.subTick == 0
            in
            if model.running then
                if isEightSub then
                    if model.subTick == 0 then
                        if nextBeat == 0 then
                            let
                                maxBarNum =
                                    List.maximum (List.map .barNum model.barConfigs) |> Maybe.withDefault model.activeBarNum

                                newActiveBar =
                                    min (model.activeBarNum + 1) maxBarNum

                                newBpm =
                                    bpmForBar newActiveBar model.barConfigs

                                newBpmStr =
                                    String.fromInt newBpm
                            in
                            ( { model
                                | flash = True
                                , currentBeat = nextBeat
                                , subTick = 1
                                , showHighlight = True
                                , activeBarNum = newActiveBar
                                , bpm = newBpm
                                , bpmInput = newBpmStr
                              }
                            , beatClick "primary"
                            )

                        else
                            ( { model | flash = True, currentBeat = nextBeat, subTick = 1, showHighlight = True }
                            , beatClick "primary"
                            )

                    else
                        ( { model | flash = True, subTick = 0, showHighlight = False }
                        , beatClick "sub"
                        )

                else if nextBeat == 0 then
                    let
                        maxBarNum =
                            List.maximum (List.map .barNum model.barConfigs) |> Maybe.withDefault model.activeBarNum

                        newActiveBar =
                            min (model.activeBarNum + 1) maxBarNum

                        newBpm =
                            bpmForBar newActiveBar model.barConfigs

                        newBpmStr =
                            String.fromInt newBpm

                        beatType =
                            case currentSubdivision of
                                Just sub ->
                                    if sub.name == "Straight Quarters" then
                                        "primary"

                                    else if
                                        List.member nextBeat
                                            (let
                                                bl =
                                                    List.foldl (\n ( acc, idx ) -> ( idx :: acc, idx + n )) ( [], 0 ) sub.groups |> Tuple.first |> List.reverse
                                             in
                                             bl
                                            )
                                    then
                                        "primary"

                                    else
                                        "sub"

                                Nothing ->
                                    if nextBeat == 0 then
                                        "primary"

                                    else
                                        "sub"
                    in
                    ( { model
                        | flash = True
                        , currentBeat = nextBeat
                        , activeBarNum = newActiveBar
                        , bpm = newBpm
                        , bpmInput = newBpmStr
                      }
                    , beatClick beatType
                    )

                else
                    ( { model | flash = True, currentBeat = nextBeat }
                    , beatClick
                        (case currentSubdivision of
                            Just sub ->
                                if sub.name == "Straight Quarters" then
                                    if nextBeat == 0 then
                                        "primary"

                                    else
                                        "sub"

                                else if
                                    List.member nextBeat
                                        (let
                                            bl =
                                                List.foldl (\n ( acc, idx ) -> ( idx :: acc, idx + n )) ( [], 0 ) sub.groups |> Tuple.first |> List.reverse
                                         in
                                         bl
                                        )
                                then
                                    "primary"

                                else
                                    "sub"

                            Nothing ->
                                "sub"
                        )
                    )

            else
                ( model, Cmd.none )

        AdvanceBeat ->
            ( model, Cmd.none )

        SetBpm newBpm ->
            ( { model | bpm = newBpm, bpmInput = String.fromInt newBpm }, Cmd.none )

        SetBpmInput inp ->
            ( { model | bpmInput = inp }, Cmd.none )

        SetBpmFromInput ->
            case String.toInt model.bpmInput of
                Just bpmVal ->
                    ( { model | bpm = bpmVal }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )



-- SUBSCRIPTIONS


{-|

    Subscriptions for clock ticks, only active while running.
    Interval adapts for 8th note subdivisions and time signature.

-}
subscriptions : Model -> Sub Msg
subscriptions model =
    if model.running then
        let
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

            mult =
                case currentSubdivision of
                    Just sub ->
                        if model.tsNum == 4 && model.tsDen == 4 && sub.name == "8th Subdivision" then
                            2

                        else
                            1

                    Nothing ->
                        1

            interval =
                60000 / toFloat model.bpm * (4 / toFloat model.tsDen) / toFloat mult
        in
        Time.every interval (\_ -> Beat)

    else
        Sub.none



-- VIEW


{-|

    The main view function orchestrates UI, delegating to helpers for BPM control, time signature, subdivisions, and dots.

-}
view : Model -> Html Msg
view model =
    let
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

        totalBeats =
            case currentSubdivision of
                Just sub ->
                    if model.tsNum == 4 && model.tsDen == 4 && sub.name == "8th Subdivision" then
                        4

                    else
                        List.sum sub.groups

                Nothing ->
                    model.tsNum
    in
    div
        [ style "font-family" "sans-serif"
        , style "display" "flex"
        , style "height" "100vh"
        , style "margin" "0"
        ]
        [ viewSidebar model
        , div [ style "flex-grow" "1", style "text-align" "center", style "margin-top" "40px" ]
            [ viewBpmControl model
            , viewTimeSignature model
            , viewStartStop model
            , viewSubdivisionSelector model currentSubOptions
            , div [ style "margin" "1.5em 0" ] (viewBeatDots model currentSubdivision totalBeats)
            ]
        ]



-- BPM lookup helper for a bar number from change points


bpmForBar : Int -> List BarConfig -> Int
bpmForBar barNum barConfigs =
    let
        eligible =
            List.filter (\bc -> bc.barNum <= barNum) barConfigs
    in
    case List.reverse eligible of
        bc :: _ ->
            bc.bpm

        [] ->
            120



-- fallback, should never occur due to bar 1 always present
-- VIEW HELPERS


viewSidebar : Model -> Html Msg
viewSidebar model =
    let
        barRow idx bar =
            let
                sel =
                    bar.barNum == model.activeBarNum
            in
            div
                [ style "display" "flex"
                , style "align-items" "center"
                , style "margin-bottom" "0.6em"
                , style "background"
                    (if sel then
                        "#edf5e1"

                     else
                        "#fafafa"
                    )
                , style "border-radius" "6px"
                , style "padding" "0.3em 0.5em"
                , style "border"
                    (if sel then
                        "2px solid #4caf50"

                     else
                        "1px solid #ddd"
                    )
                ]
                [ Html.input
                    [ Html.Attributes.type_ "number"
                    , Html.Attributes.min "1"
                    , Html.Attributes.value (String.fromInt bar.barNum)
                    , Html.Attributes.style "width" "44px"
                    , Html.Events.onInput
                        (\val ->
                            case String.toInt val of
                                Just n ->
                                    SetBarNumber idx n

                                Nothing ->
                                    SetBarNumber idx bar.barNum
                        )
                    , style "margin-right" "6px"
                    ]
                    []
                , span [] [ text ":" ]
                , Html.input
                    [ Html.Attributes.type_ "number"
                    , Html.Attributes.min "30"
                    , Html.Attributes.max "240"
                    , Html.Attributes.value (String.fromInt bar.bpm)
                    , Html.Attributes.style "width" "50px"
                    , Html.Attributes.style "margin" "0 7px 0 7px"
                    , Html.Events.onInput
                        (\s ->
                            case String.toInt s of
                                Just v ->
                                    SetBarBpm idx (clamp 30 240 v)

                                Nothing ->
                                    SetBarBpm idx bar.bpm
                        )
                    ]
                    []
                , button
                    [ style "margin-left" "2px"
                    , style "outline" "none"
                    , style "background"
                        (if sel then
                            "#4caf50"

                         else
                            "#eee"
                        )
                    , style "color"
                        (if sel then
                            "#fff"

                         else
                            "#444"
                        )
                    , style "border-radius" "4px"
                    , style "padding" "0.08em 0.7em"
                    , style "border" "1px solid #aaa"
                    , onClick (SetActiveBar bar.barNum)
                    ]
                    [ text
                        (if sel then
                            "Active"

                         else
                            "Select"
                        )
                    ]
                , if List.length model.barConfigs > 1 then
                    button
                        [ style "margin-left" "8px"
                        , style "background" "#ffcdd2"
                        , style "color" "#b71c1c"
                        , style "border-radius" "5px"
                        , style "padding" "0.08em 0.5em"
                        , style "border" "1px solid #c62828"
                        , onClick (RemoveBar idx)
                        ]
                        [ text "Remove" ]

                  else
                    text ""
                ]
    in
    div
        [ style "width" "240px"
        , style "padding" "28px 13px 0 13px"
        , style "background" "#f5f5f5"
        , style "border-right" "1px solid #ccc"
        , style "min-height" "100vh"
        ]
        ([ div [ style "font-weight" "600", style "margin-bottom" "1.1em", style "font-size" "19px" ] [ text "Bars" ] ]
            ++ (case model.sidebarError of
                    Just msg ->
                        [ div [ style "color" "#b71c1c", style "margin-bottom" "0.7em", style "font-size" "14px" ] [ text msg ] ]

                    Nothing ->
                        []
               )
            ++ List.indexedMap (\idx bar -> barRow idx bar) model.barConfigs
            ++ [ button
                    [ style "margin-top" "0.7em"
                    , style "background" "#2196f3"
                    , style "color" "#fff"
                    , style "border-radius" "7px"
                    , style "padding" "0.23em 1.4em"
                    , style "border" "1px solid #1565c0"
                    , style "font-size" "15px"
                    , onClick AddBar
                    ]
                    [ text "+ Add Bar" ]
               ]
        )


viewBpmControl : Model -> Html Msg
viewBpmControl model =
    let
        bpmValue =
            bpmForBar model.activeBarNum model.barConfigs
    in
    div [ style "display" "flex", style "align-items" "center", style "justify-content" "center" ]
        [ span [] [ text "BPM: " ]
        , inputSlider bpmValue
        , inputBpmBox bpmValue model
        ]


viewTimeSignature : Model -> Html Msg
viewTimeSignature model =
    let
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
    in
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


viewStartStop : Model -> Html Msg
viewStartStop model =
    div [ style "margin" "2em 0" ]
        [ button [ onClick StartStop ]
            [ text
                (if model.running then
                    "Stop"

                 else
                    "Start"
                )
            ]
        ]


viewSubdivisionSelector : Model -> List TimeSigOptions -> Html Msg
viewSubdivisionSelector model currentSubOptions =
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


viewBeatDots : Model -> Maybe Subdivision -> Int -> List (Html Msg)
viewBeatDots model currentSubdivision totalBeats =
    let
        isEightSub =
            case currentSubdivision of
                Just sub ->
                    model.tsNum == 4 && model.tsDen == 4 && sub.name == "8th Subdivision"

                Nothing ->
                    False
    in
    List.map
        (\i ->
            let
                isPrimary =
                    case currentSubdivision of
                        Just sub ->
                            if isEightSub then
                                True

                            else if sub.name == "Straight Quarters" then
                                i == 0

                            else
                                let
                                    boundaries =
                                        List.foldl (\n ( acc, idx ) -> ( idx :: acc, idx + n )) ( [], 0 ) sub.groups |> Tuple.first |> List.reverse
                                in
                                List.member i boundaries

                        Nothing ->
                            i == 0

                isCurrent =
                    (not isEightSub && (i == model.currentBeat)) || (isEightSub && i == model.currentBeat && model.showHighlight)

                bgColor =
                    if isEightSub then
                        if isCurrent && model.showHighlight then
                            "#4caf50"

                        else
                            "#bbb"

                    else if isCurrent then
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


inputBpmBox : Int -> Model -> Html Msg
inputBpmBox bpmValue model =
    Html.input
        [ Html.Attributes.type_ "number"
        , Html.Attributes.min "30"
        , Html.Attributes.max "240"
        , Html.Attributes.value (String.fromInt bpmValue)
        , Html.Attributes.style "width" "60px"
        , Html.Attributes.style "margin-left" "10px"
        , Html.Events.onInput SetBpmInput
        , Html.Events.onBlur SetBpmFromInput
        ]
        []



-- FLASH HANDLING (Update wrapper to reset flash after rendering)


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



-- MAIN ENTRY


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = updateWithFlash
        , subscriptions = subscriptions
        , view = view
        }
