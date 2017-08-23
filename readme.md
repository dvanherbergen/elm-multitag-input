# Multi-Tag Input

Tag input field supporting autocomplete for multiple tag types.
This component is designed to be used as an embedded ELM component in JSF (integrated using javascript) and Angular (integrated using ng-elm) applications.


## Features

- Object backed. Every tag corresponds to a tag object.
```
  { "id": "tag identifier",
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


## Usage



## Building

```
npm install
npm run build
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

- tabindex
- focus on inputfield if clicked anywhere in mti-box
- do not show suggestions if no result was found
- enter text + press tab iso enter -> no tag added
- autocomplete show empty lists
- entering value results in red flash before it is resolved..
- clicking anywhere in the field should focus on input
- mouse selection doesn't work
- highlighting of autocomplete matches is case sensitive
- pressing enter submits the form
- update documentation
- live demo?






