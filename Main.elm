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
    , tsNum : Int -- numerator (beats per measure)
    , tsDen : Int -- denominator (note value that gets the beat)
    , currentBeat : Int
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { bpm = 120, running = False, flash = False, tsNum = 4, tsDen = 4, currentBeat = 0 }
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
    | SetTimeSig Int Int
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
                60000 / toFloat model.bpm
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
                                    -- green for primary

                                else
                                    "#2196f3"
                                -- blue for subdivisions

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
            div []
                [ span [] [ text "BPM: " ]
                , inputSlider model.bpm
                , span [ style "margin-left" "10px" ] [ text (String.fromInt model.bpm) ]
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
