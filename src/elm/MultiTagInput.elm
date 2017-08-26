port module Main exposing (..)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Http
import Dom
import Task
import Json.Decode as Decode exposing (field, string, int)
import Json.Encode as Encode
import Json.Decode.Pipeline as Pipeline
import List exposing ((::))


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


unknownType : String
unknownType =
    "unknown"


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
    , multiType : Bool
    , size : Int
    , tabIndex : Int
    , autoFocus : Bool
    }


type alias Tag =
    { label : String
    , typeName : String
    , source : Maybe Decode.Value
    }


type alias TagType =
    { config : TagTypeConfig
    , suggestions : List Tag
    , enabled : Bool
    }


type alias TagTypeConfig =
    { title : String
    , name : String
    , autoCompleteURL : String
    }


type alias Flags =
    { tagTypes : List TagTypeConfig
    , tagResolveURL : String
    , id : String
    , multiType : Bool
    , size : Int
    , tabIndex : Int
    , autoFocus : Bool
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( Model flags.id
        []
        ""
        (initTagTypes flags.tagTypes)
        False
        Nothing
        ""
        0
        flags.tagResolveURL
        flags.multiType
        flags.size
        flags.tabIndex
        flags.autoFocus
    , Cmd.none
    )


initTagTypes : List TagTypeConfig -> List TagType
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
    div
        [ onKeyDownPreventDefault (model.inputText == "") (not <| isNewTagAllowed model)
        ]
        [ div
            [ class "mti-box"
            , onClick Focus
            ]
            [ text model.error
            , renderTags model
            ]
        , renderDropDown model
        ]


renderTags : Model -> Html Msg
renderTags model =
    model.tags
        |> List.map (renderTag model)
        |> List.reverse
        |> List.append [ renderInput model ]
        |> List.reverse
        |> ul []


renderTag : Model -> Tag -> Html Msg
renderTag model tag =
    let
        tagClass =
            if (tag.typeName == unknownType || (isTagTypeEnabled tag.typeName model)) then
                tag.typeName
            else
                "error"
    in
        li
            [ class tagClass ]
            [ text tag.label
            , span
                [ class "mti-close"
                , onClick (RemoveTag tag.label)
                ]
                []
            ]


renderInput : Model -> Html Msg
renderInput model =
    let
        duplicateEntry =
            tagExists model.inputText model.tags
    in
        input
            [ id model.id
            , tabindex model.tabIndex
            , on "keydown" (Decode.map KeyDown keyCode)
            , onInput Input
            , autofocus model.autoFocus
            , autocomplete False
            , value model.inputText
            , if duplicateEntry then
                class "mti-duplicate"
              else
                class ""
            ]
            []


renderDropDown : Model -> Html Msg
renderDropDown model =
    let
        renderDropDownSuggestionsAndHighlightSelected =
            renderDropDownSuggestions model

        suggestionsAvailable =
            model.tagTypes
                |> List.filter (\t -> t.enabled && not (List.isEmpty t.suggestions))
                |> List.isEmpty
                |> not
    in
        div
            [ if model.showSuggestions && suggestionsAvailable then
                class "mti-dropdown"
              else
                class "mti-dropdown hidden"
            , onMouseOut HideSuggestions
            ]
            (model.tagTypes
                |> List.filter (\t -> t.enabled && not (List.isEmpty t.suggestions))
                |> List.map renderDropDownSuggestionsAndHighlightSelected
            )


renderDropDownSuggestions : Model -> TagType -> Html Msg
renderDropDownSuggestions model tagType =
    div []
        [ label [] [ text tagType.config.title ]
        , ul
            []
            (List.map
                (renderDropDownEntry model.selectedSuggestion model.inputText)
                tagType.suggestions
            )
        ]


renderDropDownEntry : Maybe Tag -> String -> Tag -> Html Msg
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
            case List.head <| String.indexes (String.toUpper highlightText) (String.toUpper tag.label) of
                Nothing ->
                    [ text label ]

                Just startPos ->
                    let
                        startStr =
                            String.slice 0 startPos tag.label

                        endPos =
                            startPos + String.length highlightText

                        midStr =
                            String.slice startPos (startPos + String.length highlightText) tag.label

                        endStr =
                            String.dropLeft endPos tag.label
                    in
                        if cssClass == "selected" then
                            [ text label ]
                        else
                            [ text startStr
                            , strong [] [ text midStr ]
                            , text endStr
                            ]
    in
        li
            [ class cssClass
            , onClick <| SelectTag tag
            ]
            (renderLabel tag.label highlightText)


{-| Prevent text being entered if no more tags are allowed
    and only allow submit of form when all text input has been processed
-}
onKeyDownPreventDefault : Bool -> Bool -> Attribute Msg
onKeyDownPreventDefault allowSubmit blockTextEntry =
    let
        options =
            { defaultOptions | preventDefault = True }

        filterKey code =
            if code == 13 then
                if allowSubmit then
                    Decode.succeed NotifyFormSubmitted
                else
                    Decode.succeed Noop
            else if blockTextEntry then
                Decode.succeed Noop
            else
                Decode.fail "nothing prevented..."

        decoder =
            Html.Events.keyCode
                |> Decode.andThen filterKey
    in
        onWithOptions "keydown" options decoder



{------------------------------
    JS Interop
-------------------------------}


{-| Port that allows JS to subscribe to changes in the tag list.
-}
port tagListOutput : String -> Cmd msg


{-| Port that allows JS to initialize the list of tags.
-}
port tagListInput : (String -> msg) -> Sub msg


{-| Port that allows JS to subscribe to form submit events in the field.
    The submit event is triggered when the user presses Enter whilst no Tag is being entered.
-}
port formSubmitEvent : String -> Cmd msg



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
    | ProcessSuggestions Int String (Result Http.Error (List Tag))
    | TagResponse String (Result Http.Error Tag)
    | HideSuggestions
    | NotifyTagsChanged
    | SetTags String
    | NotifyFormSubmitted


subscriptions : Model -> Sub Msg
subscriptions model =
    tagListInput SetTags


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

        ProcessSuggestions version tagTypeName (Ok suggestionList) ->
            let
                populateSuggestions tagType =
                    if tagType.config.name == tagTypeName then
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

        ProcessSuggestions version tagTypeName (Err e) ->
            { model | error = formatHttpErrorMessage e }
                |> update Noop

        TagResponse label (Ok tag) ->
            model
                |> updateTag label tag
                |> updateEnabledTagTypes
                |> update NotifyTagsChanged

        TagResponse label (Err e) ->
            { model | error = formatHttpErrorMessage e }
                |> markTagInvalid label
                |> updateEnabledTagTypes
                |> update NotifyTagsChanged

        KeyDown key ->
            if key == 13 || key == 9 then
                let
                    currentLabel =
                        String.trim model.inputText
                in
                    if (model.inputText /= "" && isTagAllowed currentLabel model) then
                        let
                            updatedModel =
                                model
                                    |> saveTag currentLabel
                                    |> clearSuggestions
                                    |> updateEnabledTagTypes

                            unresolvedTags =
                                updatedModel.tags
                                    |> List.filter (\t -> t.typeName == unknownType)
                                    |> List.map .label

                            tasks =
                                [ tagListOutput <| encodeTags updatedModel
                                , focus updatedModel
                                ]
                                    |> List.append
                                        (List.map (resolveTag updatedModel) unresolvedTags)
                                    |> Cmd.batch
                        in
                            ( updatedModel, tasks )
                    else
                        ( model, Cmd.none )
            else if (key == 8 && model.inputText == "") then
                let
                    updatedModel =
                        model
                            |> deleteLastTag
                            |> updateEnabledTagTypes
                in
                    ( updatedModel
                    , Cmd.batch
                        [ tagListOutput <| encodeTags updatedModel
                        , focus updatedModel
                        ]
                    )
            else if (key == 38) then
                model
                    |> selectPreviousSuggestion
                    |> setInputTextToSuggestion
                    |> update Noop
            else if (key == 39) then
                model
                    |> selectSuggestionInNextBlock
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
            let
                updatedModel =
                    model
                        |> removeTag label
                        |> updateEnabledTagTypes
            in
                ( updatedModel
                , Cmd.batch
                    [ tagListOutput <| encodeTags updatedModel
                    , focus updatedModel
                    ]
                )

        SelectTag tag ->
            model
                |> addTag tag
                |> clearSuggestions
                |> updateEnabledTagTypes
                |> update Focus

        Focus ->
            ( model, focus model )

        NotifyTagsChanged ->
            ( model, tagListOutput <| encodeTags model )

        NotifyFormSubmitted ->
            ( model, formSubmitEvent "" )

        SetTags value ->
            let
                tagListDecoder =
                    Decode.list decodeTag

                decodeResult =
                    Decode.decodeString tagListDecoder value

                tagValues =
                    case decodeResult of
                        Ok tags ->
                            tags

                        Err _ ->
                            []
            in
                { model | tags = tagValues }
                    |> updateEnabledTagTypes
                    |> update Noop


encodeTags : Model -> String
encodeTags model =
    List.map encodeTag model.tags
        |> Encode.list
        |> Encode.encode 4


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


newTag : String -> Tag
newTag label =
    Tag label unknownType Nothing


saveTag : String -> Model -> Model
saveTag label model =
    let
        tag =
            case model.selectedSuggestion of
                Nothing ->
                    newTag label

                Just tag ->
                    if tag.label == label then
                        tag
                    else
                        newTag label
    in
        if String.contains ";" label then
            String.split ";" label
                |> List.map newTag
                |> List.take (model.size - List.length model.tags)
                |> addTags model
        else
            addTag tag model


addTags : Model -> List Tag -> Model
addTags model tags =
    if List.isEmpty tags then
        model
    else
        let
            updatedModel =
                case List.head tags of
                    Nothing ->
                        model

                    Just aTag ->
                        addTag aTag model
        in
            tags
                |> List.drop 1
                |> addTags updatedModel


addTag : Tag -> Model -> Model
addTag tag model =
    { model
        | tags =
            if (isTagAllowed tag.label model) then
                model.tags ++ [ tag ]
            else
                model.tags
        , inputText = ""
        , selectedSuggestion = Nothing
    }
        |> incrementInputVersion


removeTag : String -> Model -> Model
removeTag label model =
    { model
        | tags =
            List.filter (\t -> t.label /= label) model.tags
    }


deleteLastTag : Model -> Model
deleteLastTag model =
    { model
        | tags =
            List.take ((List.length model.tags) - 1) model.tags
    }


{-| Replace the incomplete tag with given label in the tag list with the resolved tag.
-}
updateTag : String -> Tag -> Model -> Model
updateTag label resolvedTag model =
    let
        updatePlaceHolderTag tag =
            if (tag.label == label && tag.typeName == unknownType) then
                resolvedTag
            else
                tag
    in
        { model
            | tags = List.map updatePlaceHolderTag model.tags
        }


markTagInvalid : String -> Model -> Model
markTagInvalid label model =
    let
        updateTagStatus tag =
            if (tag.label == label && tag.typeName == unknownType) then
                { tag | typeName = "error" }
            else
                tag
    in
        { model
            | tags = List.map updateTagStatus model.tags
        }


isTagAllowed : String -> Model -> Bool
isTagAllowed label model =
    isNewTagAllowed model
        && not (tagExists label model.tags)


isNewTagAllowed : Model -> Bool
isNewTagAllowed model =
    List.length model.tags < model.size


tagExists : String -> List Tag -> Bool
tagExists label tags =
    tags
        |> List.filter (\t -> t.label == (String.trim label))
        |> List.isEmpty
        |> not


isTagTypeEnabled : String -> Model -> Bool
isTagTypeEnabled tagTypeName model =
    model.tagTypes
        |> List.filter (\c -> c.enabled && c.config.name == tagTypeName)
        |> List.isEmpty
        |> not


updateEnabledTagTypes : Model -> Model
updateEnabledTagTypes model =
    if (model.multiType) then
        model
    else
        let
            firstTagType =
                model.tags
                    |> List.filter (\t -> t.typeName /= unknownType)
                    |> List.head
                    |> Maybe.withDefault (newTag "")
                    |> .typeName

            updatedTypes =
                model.tagTypes
                    |> List.map
                        (\t -> { t | enabled = (firstTagType == unknownType || t.config.name == firstTagType) })
        in
            { model | tagTypes = updatedTypes }


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


substringList : a -> List a -> List a
substringList fromValue list =
    List.foldl
        (\a b ->
            (if ((not <| List.isEmpty b) || a == fromValue) then
                a :: b
             else
                b
            )
        )
        []
        list


selectSuggestionInNextBlock : Model -> Model
selectSuggestionInNextBlock model =
    case model.selectedSuggestion of
        Nothing ->
            model

        Just selectedTag ->
            let
                suggestions =
                    getAllSuggestions model

                suggestionsStartingFromCurrent =
                    substringList selectedTag suggestions

                firstSuggestionWithDifferentTagType =
                    suggestionsStartingFromCurrent
                        |> List.drop 1
                        |> List.head
            in
                case firstSuggestionWithDifferentTagType of
                    Nothing ->
                        model

                    Just tag ->
                        { model
                            | selectedSuggestion =
                                Just tag
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


decodeTag : Decode.Decoder Tag
decodeTag =
    Decode.value
        |> Decode.andThen decodeTagContent


decodeTagContent : Decode.Value -> Decode.Decoder Tag
decodeTagContent json =
    Pipeline.decode Tag
        |> Pipeline.required "label" string
        |> Pipeline.required "type" string
        |> Pipeline.hardcoded (Just json)


encodeTag : Tag -> Encode.Value
encodeTag tag =
    case tag.source of
        Nothing ->
            -- manually entered tags that haven't been resolved
            Encode.object
                [ ( "label", Encode.string tag.label )
                , ( "type", Encode.string tag.typeName )
                ]

        Just json ->
            -- tags retrieved from rest services
            json


fetchSuggestions : Int -> String -> TagType -> Cmd Msg
fetchSuggestions version text tagType =
    if String.length text > 2 && tagType.enabled then
        Http.send (ProcessSuggestions version tagType.config.name) (Http.get (tagType.config.autoCompleteURL ++ text) (Decode.list decodeTag))
    else
        Cmd.none


resolveTag : Model -> String -> Cmd Msg
resolveTag model label =
    Http.send (TagResponse label) (Http.get (model.resolveURL ++ label) decodeTag)
