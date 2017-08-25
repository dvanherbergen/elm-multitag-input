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



## Done

- focus on inputfield if clicked anywhere in mti-box
- enter text + press tab iso enter -> no tag added
- do not show suggestions if no result was found
- highlighting of autocomplete matches is case sensitive
- define class for unknown
- tabindex
- pressing enter submits the form
- input field wraps when still room left on same line

## TODO
- make autofocus optional
- allow paste of comma separated values
- single type field cannot tab to next field once value is entered
- arrow right should move to next list in dropdown
- mouse selection doesn't work
- update documentation
- live demo?

* change json marshalling to class
* set unknown as classtype for unresolvedtagbo
* add width:6rem to mti-input css
* add tabindex flag




