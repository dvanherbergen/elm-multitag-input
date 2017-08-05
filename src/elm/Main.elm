module Main exposing (..)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Http
import Dom
import Task
import Json.Decode as Decode exposing (field, string, int)
import Json.Decode.Pipeline as Pipeline


main : Program Flags Model Msg
main =
    programWithFlags
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



{-----------------------------
    MODEL
------------------------------}


type alias Model =
    { id : String
    , tags : List Tag
    , inputText : String
    , tagTypes : List TagType
    , showSuggestions : Bool
    , selectedSuggestion : Maybe Tag
    , error : String
    , inputVersion : Int
    , resolveURL : String
    }


type alias Options =
    { allowMixedTagEntry : Bool
    , maxTags : Int
    }


type alias Tag =
    { uuid : String
    , label : String
    , description : String
    , class : String
    }


type alias TagType =
    { config : TagConfig
    , suggestions : List Tag
    , enabled : Bool
    }


type alias TagConfig =
    { name : String
    , class : String
    , autoCompleteURL : String
    }


type alias Flags =
    { tagConfigs : List TagConfig
    , tagResolveURL : String
    , id : String
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( Model flags.id
        []
        ""
        (initTagTypes flags.tagConfigs)
        False
        Nothing
        ""
        0
        flags.tagResolveURL
    , Cmd.none
    )


initTagTypes : List TagConfig -> List TagType
initTagTypes configs =
    let
        wrapConfig cfg =
            TagType cfg [] True
    in
        List.map wrapConfig configs



{------------------------------
    VIEW
-------------------------------}


view : Model -> Html Msg
view model =
    div []
        [ div [ class "mti-box" ] [ renderTags model ]
        , renderDropDown model
        ]


renderTags model =
    model.tags
        |> List.map renderTag
        |> List.reverse
        |> List.append [ renderInput model ]
        |> List.reverse
        |> ul []


renderTag : Tag -> Html Msg
renderTag tag =
    li
        [ class tag.class ]
        [ text tag.label
        , span
            [ class "close"
            , onClick (RemoveTag tag.label)
            ]
            []
        ]


renderInput model =
    input
        [ id model.id
        , if (List.isEmpty model.tags) then
            placeholder "enter tag"
          else
            placeholder ""
        , onKeyDown KeyDown
        , onInput Input
        , autocomplete False
        , onBlur HideSuggestions
        , value model.inputText
        , if (tagExists model.inputText model.tags) then
            class "mti-duplicate"
          else
            class ""
        ]
        []


renderDropDown model =
    let
        renderDropDownSuggestionsAndHighlightSelected =
            renderDropDownSuggestions model
    in
        div
            [ if model.showSuggestions then
                class "mti-dropdown"
              else
                class "mti-dropdown hidden"
            ]
            (model.tagTypes
                |> List.map renderDropDownSuggestionsAndHighlightSelected
            )


renderDropDownSuggestions : Model -> TagType -> Html Msg
renderDropDownSuggestions model tagType =
    div []
        [ h2 [] [ text tagType.config.name ]
        , ul
            []
            (List.map
                (renderDropDownEntry model.selectedSuggestion model.inputText)
                tagType.suggestions
            )
        ]


renderDropDownEntry selectedSuggestion highlightText tag =
    let
        cssClass =
            case selectedSuggestion of
                Nothing ->
                    ""

                Just aTag ->
                    if aTag.label == tag.label then
                        "selected"
                    else
                        ""

        renderLabel label highlightText =
            case List.head <| String.indexes highlightText tag.label of
                Nothing ->
                    [ text label ]

                Just startPos ->
                    let
                        startStr =
                            String.slice 0 startPos tag.label

                        endPos =
                            startPos + String.length highlightText

                        endStr =
                            String.dropLeft endPos tag.label
                    in
                        if highlightText == label then
                            [ text label ]
                        else
                            [ text startStr
                            , strong [] [ text highlightText ]
                            , text endStr
                            ]
    in
        li
            [ class cssClass
            , onClick <| SelectTag tag
            ]
            (renderLabel tag.label highlightText)



{------------------------------
    UPDATE
-------------------------------}


type Msg
    = Noop
    | Input String
    | KeyDown Int
    | RemoveTag String
    | SelectTag Tag
    | Focus
    | FetchSuggestions Int String
    | FetchSuggestionsResult Int String (Result Http.Error (List Tag))
    | FetchTagResult String (Result Http.Error Tag)
    | HideSuggestions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Noop ->
            ( model, Cmd.none )

        Input text ->
            let
                updatedModel =
                    { model
                        | inputText = text
                    }
                        |> incrementInputVersion
            in
                if (String.length text > 2) then
                    update (FetchSuggestions updatedModel.inputVersion text) updatedModel
                else
                    updatedModel
                        |> clearSuggestions
                        |> update Noop

        HideSuggestions ->
            ( { model | showSuggestions = False }, Cmd.none )

        FetchSuggestions version text ->
            ( model
            , model.tagTypes
                |> List.map (fetchSuggestions version text)
                |> Cmd.batch
            )

        FetchSuggestionsResult version class (Ok suggestionList) ->
            let
                populateSuggestions tagType =
                    if tagType.config.class == class then
                        { tagType | suggestions = suggestionList }
                    else
                        tagType
            in
                if (model.inputVersion > version) then
                    update Noop model
                else
                    ( { model
                        | tagTypes = List.map populateSuggestions model.tagTypes
                        , showSuggestions = True
                      }
                    , Cmd.none
                    )

        FetchSuggestionsResult version class (Err e) ->
            { model | error = formatHttpErrorMessage e }
                |> update Noop

        FetchTagResult label (Ok tag) ->
            model
                |> setTagType label tag
                |> update Noop

        FetchTagResult label (Err e) ->
            { model | error = formatHttpErrorMessage e }
                |> markTagInvalid label
                |> update Noop

        KeyDown key ->
            if key == 13 then
                let
                    currentLabel =
                        String.trim model.inputText
                in
                    if (currentLabel == "") then
                        -- TODO submit form here...
                        ( model, Cmd.none )
                    else if (not (tagExists currentLabel model.tags)) then
                        ( model
                            |> saveTag currentLabel
                            |> clearSuggestions
                        , Cmd.batch
                            [ fetchTag currentLabel model
                            , focus model
                            ]
                        )
                    else
                        ( model, Cmd.none )
            else if (key == 8 && model.inputText == "") then
                model
                    |> deleteLastTag
                    |> update Focus
            else if (key == 38) then
                model
                    |> selectPreviousSuggestion
                    |> setInputTextToSuggestion
                    |> update Noop
            else if (key == 40) then
                model
                    |> selectNextSuggestion
                    |> setInputTextToSuggestion
                    |> update Noop
            else
                ( model, Cmd.none )

        RemoveTag label ->
            { model | tags = (removeTag label model.tags) }
                |> update Focus

        SelectTag tag ->
            model
                |> addTag tag
                |> clearSuggestions
                |> update Focus

        Focus ->
            ( model, focus model )


focus : Model -> Cmd Msg
focus model =
    Dom.focus model.id |> Task.attempt (always Noop)


hideSuggestions : Model -> Model
hideSuggestions model =
    { model
        | showSuggestions = False
    }


clearSuggestions : Model -> Model
clearSuggestions model =
    let
        clearTagTypeSuggestion tagType =
            { tagType | suggestions = [] }
    in
        { model
            | selectedSuggestion = Nothing
            , showSuggestions = False
            , tagTypes = List.map clearTagTypeSuggestion model.tagTypes
        }


incrementInputVersion : Model -> Model
incrementInputVersion model =
    { model
        | inputVersion = model.inputVersion + 1
    }


saveTag : String -> Model -> Model
saveTag label model =
    let
        newTag =
            case model.selectedSuggestion of
                Nothing ->
                    Tag "" label label "unknown"

                Just tag ->
                    tag
    in
        addTag newTag model


addTag : Tag -> Model -> Model
addTag tag model =
    { model
        | tags = model.tags ++ [ tag ]
        , inputText = ""
        , selectedSuggestion = Nothing
    }
        |> incrementInputVersion


removeTag label tags =
    List.filter (\t -> t.label /= label) tags


deleteLastTag : Model -> Model
deleteLastTag model =
    { model
        | tags =
            List.take ((List.length model.tags) - 1) model.tags
    }


setTagType : String -> Tag -> Model -> Model
setTagType label resolvedTag model =
    let
        updateTagType tag =
            if (tag.label == label && tag.class == "unknown") then
                { tag
                    | class = resolvedTag.class
                    , uuid = resolvedTag.uuid
                    , label = resolvedTag.label
                    , description = resolvedTag.description
                }
            else
                tag
    in
        { model
            | tags = List.map updateTagType model.tags
        }


markTagInvalid : String -> Model -> Model
markTagInvalid label model =
    let
        updateTagStatus tag =
            if (tag.label == label && tag.class == "unknown") then
                { tag | class = "error" }
            else
                tag
    in
        { model
            | tags = List.map updateTagStatus model.tags
        }


tagExists : String -> List Tag -> Bool
tagExists label tags =
    tags
        |> List.filter (\t -> t.label == (String.trim label))
        |> List.isEmpty
        |> not


onKeyDown : (Int -> msg) -> Attribute msg
onKeyDown tagger =
    on "keydown" (Decode.map tagger keyCode)


selectNextSuggestion : Model -> Model
selectNextSuggestion model =
    let
        suggestions =
            getAllSuggestions model
    in
        case model.selectedSuggestion of
            Nothing ->
                { model | selectedSuggestion = List.head suggestions }

            Just tag ->
                { model
                    | selectedSuggestion =
                        suggestions
                            |> getNext tag
                }


getAllSuggestions : Model -> List Tag
getAllSuggestions model =
    List.map .suggestions model.tagTypes
        |> List.concat


selectPreviousSuggestion : Model -> Model
selectPreviousSuggestion model =
    case model.selectedSuggestion of
        Nothing ->
            model

        Just tag ->
            { model
                | selectedSuggestion =
                    model
                        |> getAllSuggestions
                        |> getPrevious tag
            }


setInputTextToSuggestion : Model -> Model
setInputTextToSuggestion model =
    let
        t =
            case model.selectedSuggestion of
                Nothing ->
                    model.inputText

                Just tag ->
                    tag.label
    in
        { model | inputText = t }
            |> incrementInputVersion


getNext : a -> List a -> Maybe a
getNext element list =
    list
        |> List.drop 1
        |> (\a b -> List.map2 (,) a b) list
        |> List.filter (\( current, next ) -> current == element)
        |> List.map (\( current, next ) -> next)
        |> List.head


getPrevious : a -> List a -> Maybe a
getPrevious element list =
    list
        |> List.drop 1
        |> (\a b -> List.map2 (,) b a) list
        |> List.filter (\( current, previous ) -> current == element)
        |> List.map (\( current, previous ) -> previous)
        |> List.head


formatHttpErrorMessage : Http.Error -> String
formatHttpErrorMessage error =
    case error of
        Http.BadUrl desc ->
            "Bad url: " ++ desc

        Http.Timeout ->
            "Connection Timeout"

        Http.BadStatus response ->
            "Bad status: HTTP " ++ toString response.status ++ " : " ++ response.body

        Http.BadPayload message response ->
            "Unexpected Payload: " ++ message

        Http.NetworkError ->
            "Network error"


decodeTag : String -> Decode.Decoder Tag
decodeTag class =
    Pipeline.decode Tag
        |> Pipeline.required "uuid" string
        |> Pipeline.required "label" string
        |> Pipeline.required "description" string
        |> Pipeline.optional "class" string class


fetchSuggestions : Int -> String -> TagType -> Cmd Msg
fetchSuggestions version text tagType =
    if String.length text > 2 && tagType.enabled then
        Http.send (FetchSuggestionsResult version tagType.config.class) (Http.get (tagType.config.autoCompleteURL ++ text) (Decode.list (decodeTag tagType.config.class)))
    else
        Cmd.none


fetchTag : String -> Model -> Cmd Msg
fetchTag label model =
    Http.send (FetchTagResult label) (Http.get (model.resolveURL ++ label) (decodeTag ""))
