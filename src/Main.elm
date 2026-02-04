port module Main exposing (main)

import Browser
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (disabled, placeholder, style, type_, value)
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
    , barConfigsEnabled : Bool
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
      , barConfigsEnabled = False
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
    | SetBarConfigsEnabled Bool


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
            if model.barConfigsEnabled then
                findBarConfigMetronome newBar model.barConfig

            else
                model.metronome

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

        bc : List BarConfig
        bc =
            updateIf (\b -> b.bar == bar) (\b -> { b | metronome = setBpm metronome bpm }) model.barConfig
    in
    { model | barConfig = bc }


setBarConfigTimeSignature : Model -> Int -> TimeSignature -> Model
setBarConfigTimeSignature model bar timeSignature =
    let
        metronome : Metronome
        metronome =
            findBarConfigMetronome bar model.barConfig

        bc : List BarConfig
        bc =
            updateIf (\b -> b.bar == bar) (\b -> { b | metronome = setTimeSignature metronome timeSignature }) model.barConfig
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

        SetBarConfigsEnabled enabled ->
            ( { model | barConfigsEnabled = enabled }, Cmd.none )


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
                                        "#ffe369"

                                    else
                                        "#7ec1fa"

                                else
                                    "#d8e1fa"

                            borderCol : String
                            borderCol =
                                if isCurrent then
                                    "#3561f6"

                                else
                                    "#b9c8e8"

                            shadow : String
                            shadow =
                                if isCurrent then
                                    "0 0 0 6px rgba(54,97,246,0.10)"

                                else
                                    "none"

                            size : String
                            size =
                                if isCurrent then
                                    "32px"

                                else
                                    "22px"
                        in
                        span
                            [ style "display" "inline-block"
                            , style "width" size
                            , style "height" size
                            , style "border-radius" "50%"
                            , style "background" color
                            , style "border" ("2.5px solid " ++ borderCol)
                            , style "box-shadow" shadow
                            , style "transition" "all .18s"
                            ]
                            []
                    )
    in
    div [ style "display" "flex", style "justify-content" "center", style "margin" "30px 0 12px 0", style "gap" "7px" ] dots


view : Model -> Html Msg
view model =
    div
        [ style "font-family" "sans-serif"
        , style "display" "flex"
        , style "height" "100vh"
        , style "margin" "0"
        ]
        [ viewSidebar model
        , div [ style "flex-grow" "1", style "display" "flex", style "flex-direction" "column", style "align-items" "center", style "justify-content" "center", style "height" "100vh" ]
            [ div
                [ style "background" "linear-gradient(135deg,#f9fafd 65%,#e5edff 100%)"
                , style "border" "1px solid #e1e7f0"
                , style "border-radius" "20px"
                , style "box-shadow" "0 8px 32px -8px rgba(44,50,120,0.13), 0 1.5px 8px 0 rgba(80,110,185,0.09)"
                , style "padding" "36px 34px 34px 34px"
                , style "width" "420px"
                , style "max-width" "90vw"
                , style "display" "flex"
                , style "flex-direction" "column"
                , style "align-items" "center"
                , style "margin-top" "0"
                ]
                [ viewBpmControl model
                , viewStartStop model
                , viewBeatDots model
                ]
            ]
        ]


viewBpmControl : Model -> Html Msg
viewBpmControl model =
    div [ style "display" "flex", style "align-items" "center", style "justify-content" "center", style "gap" "22px", style "margin-bottom" "20px" ]
        [ span [ style "font-weight" "bold", style "font-size" "18px", style "color" "#245" ] [ text ("BPM: " ++ String.fromFloat model.metronome.bpm) ]
        , Html.input
            [ type_ "range"
            , Html.Attributes.min "30"
            , Html.Attributes.max "240"
            , value (String.fromFloat model.metronome.bpm)
            , onInput (String.toFloat >> Maybe.withDefault model.metronome.bpm >> SetBpm)
            , disabled model.barConfigsEnabled
            , style "accent-color" "#3a58ed"
            , style "width" "135px"
            , style "height" "6px"
            , style "background" "linear-gradient(90deg,#dae3ff 30%,#a6c3ff 100%)"
            , style "border-radius" "8px"
            ]
            []
        , Html.select
            [ Html.Attributes.value (timeSignatureToString model.metronome.timeSignature)
            , disabled model.barConfigsEnabled
            , style "padding" "8px 20px 8px 10px"
            , style "border-radius" "9px"
            , style "border" "1.5px solid #d2d7e9"
            , style "background" "#f5f8ff"
            , style "font-size" "16px"
            , style "outline" "none"
            , style "transition" "border-color .2s"
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
    div [ style "margin" "16px 0 24px 0", style "display" "flex", style "justify-content" "center" ]
        [ if model.metronome.active then
            button
                [ onClick Stop
                , style "background" "linear-gradient(90deg,#fb7171 20%,#ffb8b8 95%)"
                , style "color" "white"
                , style "border" "none"
                , style "border-radius" "10px"
                , style "box-shadow" "0 2px 12px 0 rgba(240,80,80,0.17)"
                , style "padding" "12px 38px"
                , style "font-size" "17px"
                , style "font-weight" "bold"
                , style "letter-spacing" ".5px"
                , style "transition" "filter .15s"
                , style "cursor" "pointer"
                ]
                [ text "Stop" ]

          else
            button
                [ onClick Start
                , style "background" "linear-gradient(90deg,#5a7efe 15%,#6de9fb 95%)"
                , style "color" "white"
                , style "border" "none"
                , style "border-radius" "10px"
                , style "box-shadow" "0 2px 12px 0 rgba(64,90,240,0.13)"
                , style "padding" "12px 38px"
                , style "font-size" "17px"
                , style "font-weight" "bold"
                , style "letter-spacing" ".5px"
                , style "transition" "filter .15s"
                , style "cursor" "pointer"
                ]
                [ text "Start" ]
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
        [ div [ style "display" "flex", style "align-items" "center", style "margin-bottom" "16px" ]
            [ Html.input
                [ Html.Attributes.type_ "checkbox"
                , Html.Attributes.checked model.barConfigsEnabled
                , Html.Events.onCheck SetBarConfigsEnabled
                , style "margin-right" "12px"
                , style "width" "18px"
                , style "height" "18px"
                ]
                []
            , span [ style "font-weight" "bold", style "font-size" "16px", style "color" "#293477" ] [ text "Enable bar configs" ]
            ]
        , div [ style "margin-bottom" "28px", style "font-size" "22px", style "font-weight" "bold", style "letter-spacing" "1px" ] [ text "Bar Configs" ]
        , div []
            (List.map viewSidebarBarCard model.barConfig)
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
