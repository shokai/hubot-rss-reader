Hubot RSS Reader
================
RSS Reader for each Chat Channels, works with Hubot.

[![Build Status](https://travis-ci.org/shokai/hubot-rss-reader.svg?branch=master)](https://travis-ci.org/shokai/hubot-rss-reader)

- https://github.com/shokai/hubot-rss-reader
- https://www.npmjs.org/package/hubot-rss-reader


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

### Configure (ENV var)

export HUBOT_RSS_INTERVAL=600  # 600 sec (default)
export DEBUG=hubot-rss-reader  # debug print


Usage
-----

### add

    hubot rss add https://github.com/shokai.atom
    # or
    hubot rss register https://github.com/shokai.atom


### delete

    hubot rss delete https://github.com/shokai.atom


### list

    hubot rss list


Test
----

    % npm install

    % grunt
    # or
    % npm test
