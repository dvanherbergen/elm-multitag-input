# Multi-Tag Input

Tag input field supporting autocomplete for multiple tag types.
This component is designed to be used as an embedded ELM component in JSF (using javascript) and Angular (using ng-elm) applications.


## Features

- Multi-Type.
- Async.
- Autocomplete.
- Object backed. Every tag corresponds to an object.


## Usage



## Building



## Support

- Found a bug? Raise an issue.
- Want a new feature? Raise a pull request.





## TODO


- delayed lookup of exact tag match
- allow only single value to be selected
- allow only single type to be selected


- integration from JSF
- integration using ng-elm

- example tags input ngjs
  http://mbenford.github.io/ngTagsInput/

## Open questions:

- how to set selection value from popup window?
    * https://stackoverflow.com/questions/4350223/passing-data-between-a-parent-window-and-a-child-popup-window-with-jquery

- how to pass values back to JSF for query?

- how to load values from query parameters

- how to handle validation

- how to allow external manipulation of values, e.g. filter deselection / changes thru popup




Install all dependencies using the handy `reinstall` script:
```
npm install
```
*This does a clean (re)install of all npm and elm packages, plus a global elm install.*


### Serve locally:
```
npm start
```
* Access app at `http://localhost:8080/`
* Get coding! The entry point file is `src/elm/Main.elm`
* Browser will refresh automatically on any file changes..