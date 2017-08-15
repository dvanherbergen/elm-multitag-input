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
    , multiType : Bool
    , multiValue : Bool
    }


type alias Tag =
    { id : String
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
    , multiType : Bool
    , multiValue : Bool
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
        flags.multiType
        flags.multiValue
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
    div [ onKeyDownPreventDefault <| not <| isNewTagAllowed model ]
        [ div [ class "mti-box" ] [ renderTags model ]
        , renderDropDown model
        ]


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
            if (isTagTypeEnabled tag.class model) then
                tag.class
            else
                "invalid"
    in
        li
            [ class tagClass ]
            [ text tag.label
            , span
                [ class "close"
                , onClick (RemoveTag tag.label)
                ]
                []
            ]


renderInput model =
    let
        tagAllowed =
            isTagAllowed model.inputText model
    in
        input
            [ id model.id
            , if (List.isEmpty model.tags) then
                placeholder "enter tag"
              else
                placeholder ""
            , on "keydown" (Decode.map KeyDown keyCode)
            , onInput Input
            , autocomplete False
            , onBlur HideSuggestions
            , value model.inputText
            , if tagAllowed then
                class ""
              else
                class "mti-duplicate"
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
                |> List.filter (\t -> t.enabled)
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



{--
    Prevent text being entered if no more tags are allowed
--}


onKeyDownPreventDefault : Bool -> Attribute Msg
onKeyDownPreventDefault block =
    let
        options =
            { defaultOptions | preventDefault = True }

        filterKey code =
            if block then
                Decode.succeed Noop
            else
                Decode.fail "ignored input"

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

        ProcessSuggestions version class (Ok suggestionList) ->
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

        ProcessSuggestions version class (Err e) ->
            { model | error = formatHttpErrorMessage e }
                |> update Noop

        TagResponse label (Ok tag) ->
            model
                |> setTagType label tag
                |> updateEnabledTagTypes
                |> update NotifyTagsChanged

        TagResponse label (Err e) ->
            { model | error = formatHttpErrorMessage e }
                |> markTagInvalid label
                |> updateEnabledTagTypes
                |> update NotifyTagsChanged

        KeyDown key ->
            if key == 13 then
                let
                    currentLabel =
                        String.trim model.inputText
                in
                    if (currentLabel == "") then
                        -- TODO submit form here...
                        ( model, Cmd.none )
                    else if (isTagAllowed currentLabel model) then
                        ( model
                            |> saveTag currentLabel
                            |> clearSuggestions
                            |> updateEnabledTagTypes
                        , Cmd.batch
                            [ resolveTag currentLabel model
                            , tagListOutput <| encodeTags model
                            , focus model
                            ]
                        )
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


setTagType : String -> Tag -> Model -> Model
setTagType label resolvedTag model =
    let
        updateTagType tag =
            if (tag.label == label && tag.class == "unknown") then
                { tag
                    | class = resolvedTag.class
                    , id = resolvedTag.id
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


isTagAllowed : String -> Model -> Bool
isTagAllowed label model =
    isNewTagAllowed model
        && not (tagExists label model.tags)


isNewTagAllowed : Model -> Bool
isNewTagAllowed model =
    (model.multiValue || (List.length model.tags == 0))


tagExists : String -> List Tag -> Bool
tagExists label tags =
    tags
        |> List.filter (\t -> t.label == (String.trim label))
        |> List.isEmpty
        |> not


isTagTypeEnabled : String -> Model -> Bool
isTagTypeEnabled class model =
    model.tagTypes
        |> List.filter (\c -> c.enabled && c.config.class == class)
        |> List.isEmpty
        |> not


updateEnabledTagTypes : Model -> Model
updateEnabledTagTypes model =
    if (model.multiType) then
        model
    else
        let
            firstTagClass =
                model.tags
                    |> List.filter (\t -> t.class /= "")
                    |> List.head
                    |> Maybe.withDefault (Tag "" "" "" "")
                    |> .class

            updatedTypes =
                model.tagTypes
                    |> List.map
                        (\t -> { t | enabled = (firstTagClass == "" || t.config.class == firstTagClass) })
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
    Pipeline.decode Tag
        |> Pipeline.required "id" string
        |> Pipeline.required "label" string
        |> Pipeline.required "description" string
        |> Pipeline.required "class" string


encodeTag : Tag -> Encode.Value
encodeTag tag =
    Encode.object
        [ ( "id", Encode.string tag.id )
        , ( "label", Encode.string tag.label )
        , ( "description", Encode.string tag.description )
        , ( "class", Encode.string tag.class )
        ]


fetchSuggestions : Int -> String -> TagType -> Cmd Msg
fetchSuggestions version text tagType =
    if String.length text > 2 && tagType.enabled then
        Http.send (ProcessSuggestions version tagType.config.class) (Http.get (tagType.config.autoCompleteURL ++ text) (Decode.list decodeTag))
    else
        Cmd.none


resolveTag : String -> Model -> Cmd Msg
resolveTag label model =
    Http.send (TagResponse label) (Http.get (model.resolveURL ++ label) decodeTag)
