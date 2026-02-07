port module Main exposing (main)

import Browser
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (disabled, placeholder, type_, value)
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

            denominator : Float
            denominator =
                toFloat (Tuple.second model.metronome.timeSignature)

            multiplier : Float
            multiplier =
                4 / denominator

            interval : Float
            interval =
                (minute / model.metronome.bpm) * multiplier
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
                    (\_ ->
                        span
                            []
                            []
                    )
    in
    div [] dots


view : Model -> Html Msg
view model =
    div
        []
        [ viewSidebar model
        , div []
            [ div
                []
                [ viewBpmControl model
                , viewStartStop model
                , viewBeatDots model
                ]
            ]
        ]


viewBpmControl : Model -> Html Msg
viewBpmControl model =
    div [ style "display" "flex", style "align-items" "center", style "justify-content" "center", style "gap" "22px", style "margin-bottom" "20px" ]
        [ span [] [ text ("BPM: " ++ String.fromFloat model.metronome.bpm) ]
        , Html.input
            [ type_ "range"
            , Html.Attributes.min "30"
            , Html.Attributes.max "240"
            , value (String.fromFloat model.metronome.bpm)
            , onInput (String.toFloat >> Maybe.withDefault model.metronome.bpm >> SetBpm)
            , disabled model.barConfigsEnabled
            ]
            []
        , Html.select
            [ Html.Attributes.value (timeSignatureToString model.metronome.timeSignature)
            , disabled model.barConfigsEnabled
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
    div []
        [ if model.metronome.active then
            button
                [ onClick Stop
                ]
                [ text "Stop" ]

          else
            button
                [ onClick Start
                ]
                [ text "Start" ]
        ]


viewSidebarBarCard : BarConfig -> Html Msg
viewSidebarBarCard barConfig =
    div
        []
        [ div []
            [ text "Bar number"
            , Html.input
                [ type_ "number"
                , value (String.fromInt barConfig.bar)
                , Html.Attributes.min "1"
                , placeholder "Bar number"
                , onInput (String.toInt >> Maybe.withDefault barConfig.bar >> SetBarConfigBar barConfig.bar)
                ]
                []
            ]
        , div []
            [ text "BPM"
            , Html.input
                [ type_ "number"
                , value (String.fromFloat barConfig.metronome.bpm)
                , Html.Attributes.min "30"
                , Html.Attributes.max "240"
                , placeholder "BPM"
                , onInput (String.toFloat >> Maybe.withDefault barConfig.metronome.bpm >> SetBarConfigBpm barConfig.bar)
                ]
                []
            ]
        , div []
            [ text "Time signature"
            , Html.select
                [ value (timeSignatureToString barConfig.metronome.timeSignature)
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
        []
        [ div []
            [ Html.input
                [ Html.Attributes.type_ "checkbox"
                , Html.Attributes.checked model.barConfigsEnabled
                , Html.Events.onCheck SetBarConfigsEnabled
                ]
                []
            , span [] [ text "Enable bar configs" ]
            ]
        , div [] [ text "Bar Configs" ]
        , div []
            (List.map viewSidebarBarCard model.barConfig)
        , button
            [ onClick AddBarConfig
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
