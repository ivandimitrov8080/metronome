port module Main exposing (main)

import Browser
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (placeholder, style, type_, value)
import Html.Events exposing (onClick, onInput)
import List exposing (filter, sortBy)
import List.Extra exposing (takeWhile, updateIf)
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


type alias BarConfig =
    { bar : Int
    , metronome : Metronome
    }


type alias Model =
    { metronome : Metronome
    , barConfig : List BarConfig
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


lastElem : List a -> Maybe a
lastElem =
    List.foldl (Just >> always) Nothing


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


findBarConfigMetronome : Int -> List BarConfig -> Metronome
findBarConfigMetronome bar barConfig =
    case barConfig |> takeWhile (\c -> c.bar <= bar) |> lastElem of
        Just bc ->
            bc.metronome

        Nothing ->
            initMetronome


initMetronome : Metronome
initMetronome =
    { bpm = 120
    , timeSignature = ( 4, 4 )
    , subdivision = { name = "Straight Quarters", groups = [ 1, 1, 1, 1 ] }
    , active = False
    , currentBeat = 0
    , remainder = 0
    , currentBar = 0
    }


initActiveMetronome : Metronome
initActiveMetronome =
    { initMetronome | active = True }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { metronome = initMetronome
      , barConfig = [ { bar = 1, metronome = initActiveMetronome } ]
      }
    , Cmd.none
    )


type Msg
    = SetBpm Float
    | Start
    | Stop
    | SetTimeSignature TimeSignature
    | Beat
    | AddBarConfig
    | SetBarConfigBar Int Int
    | SetBarConfigBpm Int Float
    | SetBarConfigTimeSignature Int TimeSignature


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

        newBar : Int
        newBar =
            if remainder == 0 then
                model.metronome.currentBar + 1

            else
                model.metronome.currentBar

        metronome : Metronome
        metronome =
            findBarConfigMetronome newBar model.barConfig

        newCurrentBeat : Int
        newCurrentBeat =
            if model.metronome.timeSignature == metronome.timeSignature then
                let
                    previousBeat : Int
                    previousBeat =
                        model.metronome.currentBeat
                in
                previousBeat + 1

            else
                1

        newMetronome : Metronome
        newMetronome =
            { metronome | currentBeat = newCurrentBeat, remainder = remainder, currentBar = newBar }
    in
    ( { model | metronome = newMetronome }, beatClick beatType )


setBpm : Metronome -> Float -> Metronome
setBpm metronome bpm =
    { metronome | bpm = bpm }


setTimeSignature : Metronome -> TimeSignature -> Metronome
setTimeSignature metronome timeSignature =
    { metronome | timeSignature = timeSignature }


addBarConfig : Model -> Model
addBarConfig model =
    let
        lastBar : Int
        lastBar =
            case lastElem model.barConfig of
                Just c ->
                    c.bar

                Nothing ->
                    0

        bc : List BarConfig
        bc =
            List.append model.barConfig [ { bar = lastBar + 1, metronome = initActiveMetronome } ]
    in
    { model | barConfig = sortBy (\c -> c.bar) bc }


setBarConfigBar : Model -> Int -> Int -> Model
setBarConfigBar model bar newBar =
    let
        bars : List BarConfig
        bars =
            filter (\e -> e.bar == newBar) model.barConfig
    in
    if not (List.isEmpty bars) then
        model

    else
        let
            bc : List BarConfig
            bc =
                updateIf (\b -> b.bar == bar) (\b -> { b | bar = newBar }) model.barConfig
        in
        { model | barConfig = bc }


setBarConfigBpm : Model -> Int -> Float -> Model
setBarConfigBpm model bar bpm =
    let
        metronome : Metronome
        metronome =
            findBarConfigMetronome bar model.barConfig

        newMetronome : Metronome
        newMetronome =
            { metronome | bpm = bpm }

        bc : List BarConfig
        bc =
            updateIf (\b -> b.bar == bar) (\b -> { b | metronome = newMetronome }) model.barConfig
    in
    { model | barConfig = bc }


setBarConfigTimeSignature : Model -> Int -> TimeSignature -> Model
setBarConfigTimeSignature model bar timeSignature =
    let
        metronome : Metronome
        metronome =
            findBarConfigMetronome bar model.barConfig

        newMetronome : Metronome
        newMetronome =
            { metronome | timeSignature = timeSignature }

        bc : List BarConfig
        bc =
            updateIf (\b -> b.bar == bar) (\b -> { b | metronome = newMetronome }) model.barConfig
    in
    { model | barConfig = bc }


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

        AddBarConfig ->
            ( addBarConfig model, Cmd.none )

        SetBarConfigBar idx bpm ->
            ( setBarConfigBar model idx bpm, Cmd.none )

        SetBarConfigBpm idx bpm ->
            ( setBarConfigBpm model idx bpm, Cmd.none )

        SetBarConfigTimeSignature idx bpm ->
            ( setBarConfigTimeSignature model idx bpm, Cmd.none )


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
        [ viewSidebar model
        , div [ style "flex-grow" "1", style "text-align" "center", style "margin-top" "40px" ]
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


viewSidebarBarCard : BarConfig -> Html Msg
viewSidebarBarCard barConfig =
    div
        [ style "background" "linear-gradient(135deg,#fcfcff 65%,#e9efff 100%)"
        , style "border" "1px solid #e1e7f0"
        , style "border-radius" "18px"
        , style "box-shadow" "0 6px 24px -4px rgba(44,50,120,0.12), 0 1.5px 6px 0 rgba(80,110,185,0.08)"
        , style "transition" "box-shadow .2s"
        , style "margin-bottom" "24px"
        , style "padding" "24px 18px 20px 18px"
        , style "position" "relative"
        ]
        [ div [ style "margin-bottom" "14px" ]
            [ text "Bar number"
            , Html.input
                [ type_ "number"
                , value (String.fromInt barConfig.bar)
                , Html.Attributes.min "1"
                , placeholder "Bar number"
                , style "margin-left" "14px"
                , style "padding" "7px 12px"
                , style "border-radius" "9px"
                , style "border" "1.5px solid #d2d7e9"
                , style "background" "#f5f8ff"
                , style "font-size" "15px"
                , style "outline" "none"
                , style "transition" "border-color .2s"
                , onInput (String.toInt >> Maybe.withDefault barConfig.bar >> SetBarConfigBar barConfig.bar)
                ]
                []
            ]
        , div [ style "margin-bottom" "14px", style "border-top" "1px solid #e8eaf2", style "padding-top" "16px", style "margin-top" "8px" ]
            [ text "BPM"
            , Html.input
                [ type_ "number"
                , value (String.fromFloat barConfig.metronome.bpm)
                , Html.Attributes.min "30"
                , Html.Attributes.max "240"
                , placeholder "BPM"
                , style "margin-left" "14px"
                , style "padding" "7px 12px"
                , style "border-radius" "9px"
                , style "border" "1.5px solid #d2d7e9"
                , style "background" "#f5f8ff"
                , style "font-size" "15px"
                , style "outline" "none"
                , style "transition" "border-color .2s"
                , onInput (String.toFloat >> Maybe.withDefault barConfig.metronome.bpm >> SetBarConfigBpm barConfig.bar)
                ]
                []
            ]
        , div [ style "margin-bottom" "14px", style "border-top" "1px solid #e8eaf2", style "padding-top" "16px", style "margin-top" "8px" ]
            [ text "Time signature"
            , Html.select
                [ value (timeSignatureToString barConfig.metronome.timeSignature)
                , style "margin-left" "14px"
                , style "padding" "7px 12px"
                , style "border-radius" "9px"
                , style "border" "1.5px solid #d2d7e9"
                , style "background" "#f5f8ff"
                , style "font-size" "15px"
                , style "outline" "none"
                , style "transition" "border-color .2s"
                , onInput
                    (stringToTimeSignature
                        >> Maybe.withDefault barConfig.metronome.timeSignature
                        >> SetBarConfigTimeSignature barConfig.bar
                    )
                ]
                (List.map
                    (\ts ->
                        Html.option [ Html.Attributes.value (timeSignatureToString ts) ] [ text (timeSignatureToString ts) ]
                    )
                    allTimeSignatures
                )
            ]
        ]


viewSidebar : Model -> Html Msg
viewSidebar model =
    div
        [ style "width" "320px"
        , style "background" "#f7f7f7"
        , style "border-right" "1px solid #ccc"
        , style "padding" "32px 22px 22px 22px"
        , style "box-sizing" "border-box"
        , style "height" "100vh"
        , style "overflow-y" "auto"
        ]
        [ div [ style "margin-bottom" "28px", style "font-size" "22px", style "font-weight" "bold", style "letter-spacing" "1px" ] [ text "Bar Configs" ]
        , div [] (List.map viewSidebarBarCard model.barConfig)
        , button
            [ style "margin-top" "9px"
            , style "width" "100%"
            , style "padding" "10px 0"
            , style "background" "#eef"
            , style "border" "1px solid #ccd"
            , style "font-size" "15px"
            , style "border-radius" "8px"
            , onClick AddBarConfig
            ]
            [ text "+ Add Bar" ]
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }
