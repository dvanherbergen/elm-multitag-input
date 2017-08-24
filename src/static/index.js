// pull in desired CSS/SASS files
require( './styles/main.scss' );

// inject bundled Elm app into div#main
var Elm = require( '../elm/MultiTagInput' );
var app = Elm.Main.embed(
  document.getElementById('example1'),
  {
    "tagConfigs" :
      [
        { "name" : "Artikels"
        , "class" : "article"
        /*, "autoCompleteURL" : "http://tag-list.getsandbox.com/article/"*/
        , "autoCompleteURL" : "http://localhost:8080/static/temp.json?"

        }
      , { "name" : "Grvk"
        , "class" : "grvk"
        /*, "autoCompleteURL" : "http://tag-list.getsandbox.com/grvk/"*/
        , "autoCompleteURL" : "http://localhost:8080/static/temp.json?"
        }
      , { "name" : "Clusters"
        , "class" : "cluster"
       /* , "autoCompleteURL" : "http://tag-list.getsandbox.com/cluster/"*/
       , "autoCompleteURL" : "http://localhost:8080/static/temp.json?"
        }
      ],
    /* "tagResolveURL" : "http://tag-list.getsandbox.com/resolve/",*/
     "tagResolveURL" : "http://localhost:8080/static/resolve.json?q=",
    "multiType" : false,
    "multiValue" : true,
    "tabIndex" : 1,
    "id" : "ex1"
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
        "class": "article",
        "description": "1234 - Article aa"
    }, {
        "id": 1235,
        "label": "Init Article 2",
        "description": "1234 - Article bb",
        "class": "article"
    }

  ]`);


var app2 = Elm.Main.embed(
  document.getElementById('example2'),
  {
    "tagConfigs" :
      [
        { "name" : "Artikels"
        , "class" : "article"
        ,"autoCompleteURL" : "http://tag-list.getsandbox.com/article/"
        }
      , { "name" : "Grvk"
        , "class" : "grvk"
        , "autoCompleteURL" : "http://tag-list.getsandbox.com/grvk/"
        }
      , { "name" : "Clusters"
        , "class" : "cluster"
        , "autoCompleteURL" : "http://tag-list.getsandbox.com/cluster/"
        }
      ],
    "tagResolveURL" : "http://tag-list.getsandbox.com/resolve/",
    "multiType" : false,
    "multiValue" : true,
    "tabIndex" : 2,
    "id" : "ex2"
  }
  );

app2.ports.tagListOutput.subscribe(function(tags) {
        console.log('TAGS: ' + tags);
    });

app2.ports.tagListInput.send(`[
{
        "id": 1234,
        "label": "InitArticle 1" ,
        "class": "article",
        "description": "1234 - Article aa"
    }
  ]`);
