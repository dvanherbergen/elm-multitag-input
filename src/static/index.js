// pull in desired CSS/SASS files
require( './styles/main.scss' );

// inject bundled Elm app into div#main
var Elm = require( '../elm/MultiTagInput' );
var app = Elm.Main.embed(
  document.getElementById('example1'),
  {
    "tagTypes" :
      [
        { "title" : "Artikels"
        , "name" : "article"
        , "autoCompleteURL" : "http://localhost:8080/static/temp.json?"

        }
      , { "title" : "Grvk"
        , "name" : "grvk"
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


app.ports.formSubmitEvent.subscribe(function() {
        alert('Submit form here...');
    });

app.ports.tagListInput.send(`[
{
        "id": 1234,
        "label": "InitArticle 1" ,
        "type": "article",
        "description": "1234 - Article aa"
    }, {
        "id": 1235,
        "label": "Init Article 2",
        "description": "1234 - Article bb",
        "type": "article"
    }

  ]`);


var app2 = Elm.Main.embed(
  document.getElementById('example2'),
  {
    "tagTypes" :
      [
        { "title" : "Artikels"
        , "name" : "article"
        ,"autoCompleteURL" : "http://tag-list.getsandbox.com/article/"
        }
      , { "title" : "Grvk"
        , "name" : "grvk"
        , "autoCompleteURL" : "http://tag-list.getsandbox.com/grvk/"
        }
      , { "title" : "Clusters"
        , "name" : "cluster"
        , "autoCompleteURL" : "http://tag-list.getsandbox.com/cluster/"
        }
      ],
    "tagResolveURL" : "http://tag-list.getsandbox.com/resolve/",
    "multiType" : false,
    "size" : 3,
    "tabIndex" : 2,
    "id" : "ex2",
    "autoFocus" : false
  }
  );

app2.ports.tagListOutput.subscribe(function(tags) {
        console.log('TAGS: ' + tags);
    });

app2.ports.tagListInput.send(`[
{
        "id": 1234,
        "label": "InitArticle 1" ,
        "type": "article",
        "description": "1234 - Article aa"
    }
  ]`);
