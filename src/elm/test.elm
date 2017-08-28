module Main exposing (..)

import Html exposing (text)
import Json.Decode as Decode exposing (field, string, int)
import Json.Encode as Encode
import Json.Decode.Pipeline as Pipeline

i  = """ { "id" : 1} """

li  = """ [{ "id" : 1}, { "id" : 2, "test" : "value"}] """

type alias Tag = { source : Encode.Value }

f = Tag <| Encode.string i

Decode.decodeString Decode.value i


main =
    text "Hello, World!"



decodeTag = \
    Decode.value \
        |> Decode.andThen decodeSimpleTag


decodeTag2 : Decode.Value -> Decode.Decoder Tag
decodeTag2 json =
    Pipeline.decode Tag
        |> Pipeline.required "id" int
        |> Pipeline.required "label" string
        |> Pipeline.required "description" string
        |> Pipeline.required "type" string
        |> Pipeline.hardcoded json



type alias SimpleTag = { id : Int }

decodeSimpleTag = \
      Pipeline.decode SimpleTag \
          |> Pipeline.required "id" Decode.int

Decode.decodeString decodeSimpleTag i
-- Ok { id = 1 } : Result.Result String Repl.SimpleTag


decodeTagB v = \
        Pipeline.decode SimpleTag \
            |> Pipeline.required "id" Decode.int

decodeTagA = \
      Decode.value \
          |> Decode.andThen decodeTagB

Decode.decodeString decodeTagA i
-- Ok { id = 1 } : Result.Result String Repl.SimpleTag



type alias ComplexTag = { id : Int , source : Decode.Value}

decodeTagC v = \
        Pipeline.decode ComplexTag \
            |> Pipeline.required "id" Decode.int \
            |> Pipeline.hardcoded v

decodeTagD = \
      Decode.value \
          |> Decode.andThen decodeTagC


  Decode.decodeString decodeTagD i
