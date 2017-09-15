# Multi-Tag Input

Tag input field supporting autocomplete for multiple tag types.
This component is designed to be used as an embedded ELM component in JSF (integrated using javascript) and Angular (integrated using ng-elm) applications.


## Features

- Object backed. Every tag corresponds to a tag object.
```
  { "id": number,
    "class": "tag type name. also used as css class",
    "label": "text to show on tag",
    "description" : "text to show in tag tooltip"
  }
```
- Async. Users can enter a tag without waiting for the automplete option. Validation is done asynchronously afterwards. Invalid tags will get the 'invalid' class.
- Multi-Type. Allow multiple types of tags to be mixed in the same field (or not...)
- Multi-Value. The number of tags allowed is configurable.
- Multi-section utocomplete. Autocompletion that supports multiple sections. One section per allowed tag type in the same field.
- Callback on tag list change.
- Supports ; separated tag entry. Entering a string tag1;tag2 will expand into two tags.

## Config flags:

- size : maximum number of tags that may be entered
- multiType : a value of true allows different types of tags to be mixed in the same field. when false, the first tag entered determines the tag type for the remaining values in the field.



## Usage

```
var app = Elm.Main.embed(
  document.getElementById('example1'),
  {
    "tagTypes" :
      [
        { "title" : "Artikels"
        , "name" : "article"
        , "autoCompleteURL" : "http://localhost:8080/static/temp.json?"

        }
      , { "title" : "Clusters"
        , "name" : "cluster"
       , "autoCompleteURL" : "http://localhost:8080/static/temp.json?"
        }
      ],
     "tagResolveURL" : "http://localhost:8080/static/resolve.json?q=",
    "multiType" : false,
    "size" : 3,
    "tabIndex" : 1,
    "id" : "ex1",
    "autoFocus" : true
  }
  );

app.ports.tagListOutput.subscribe(function(tags) {
        console.log('TAGS: ' + tags);
    });

```    

## Building

```
npm install
npm run build

elm-package install
elm-make src\elm\MultiTagInput.elm --output MultiTagInput.js

```



## Serve locally

```
npm start
```
* Access demo app at `http://localhost:8080/`

## Support

- Found a bug? Raise an issue.
- Want a new feature? Raise a pull request.



## TODO

- update documentation
- live demo? or pics?
