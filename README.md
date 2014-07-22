Hubot RSS Reader
================
RSS Reader for each Chat Channels, works with Hubot.

- https://github.com/shokai/hubot-rss-reader


Requirements
------------

- redis-brain


Install
-------

    % npm install hubot-rss-reader -save


### edit `external-script.json`

```json
["hubot-rss-reader"]
```


Usage
-----

### add

    hubot rss add https://github.com/shokai.atom
    # or
    hubot rss register https://github.com/shokai.atom

    # register multiple Feeds separate with line-break
    hubot rss add https://github.com/shokai.atom\n
    http://shokai.org/blog/feed\n
    http://b.hatena.ne.jp/shokai/rss
    

### delete

    hubot rss delete https://github.com/shokai.atom


### list

    hubot rss list
