// pull in desired CSS/SASS files
require( './styles/main.scss' );

// inject bundled Elm app into div#main
var Elm = require( '../elm/Main' );
Elm.Main.embed( 
  document.getElementById('example1'),
  {
    "tagConfigs" : 
      [ 
        { "name" : "Artikels"
        , "class" : "article"
        , "autoCompleteURL" : "http://tag-list.getsandbox.com/article/"
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
    "maxValues" : -1,
    "id" : "ex1"
  }
  );


Elm.Main.embed( 
  document.getElementById('example2'),
  {
    "tagConfigs" : 
      [ 
        { "name" : "Artikels"
        , "class" : "article"
        , "autoCompleteURL" : "http://tag-list.getsandbox.com/article/"
        }
      , { "name" : "Grvk"
        , "class" : "grvk"
        , "autoCompleteURL" : "http://tag-list.getsandbox.com/grvk/"
        }
      ],
    "tagResolveURL" : "http://tag-list.getsandbox.com/resolve/",
    "maxValues" : 1,
    "id" : "ex2"
  }
  );

Elm.Main.embed( 
  document.getElementById('example3'),
  {
    "tagConfigs" : 
      [ 
        { "name" : "Artikels"
        , "class" : "article"
        , "autoCompleteURL" : "http://tag-list.getsandbox.com/article/"
        }
      ],
    "tagResolveURL" : "http://tag-list.getsandbox.com/resolve/",
    "maxValues" : 1,
    "id" : "ex3"
  }
  );
