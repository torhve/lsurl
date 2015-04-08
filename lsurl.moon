--

-- Lua Short URL

--(c) 2015 Tor Hveem <tor@hveem.no>

-- License: MIT

--]]

cjson = require "cjson"
redis = require "resty.redis"
hashids = require "hashids" -- https://github.com/leihog/hashids.lua

red = redis\new()
errexit = (err) ->
    ngx.log(ngx.ERR, "failed to connect: ", err)
    ngx.say('Error with database')
    ngx.exit(500)

-- Start redis connection
ok, err = red\connect("127.0.0.1", 6379)
if not ok then errexit(err)

-- REDIS Schema
-- lsurl:count -- Number of URLs
-- lsurl:url = hash
-- lsurl:hash:url = real url
-- lsurl:hash:hits = number of redirs
-- lsurl:hash:referer = list of referrers
-- lsurl:hash:useragent = list of user agents
-- lsurl:hash:visitor = list of IPS


rkey = (key, val) ->
  'lsurl:' .. key .. ':' .. val

visit = (hash) ->
  ok, err = red\incr rkey(hash, 'hits')
  ok, err = red\rpush rkey(hash, 'referer'), ngx.var.http_referer or ""
  ok, err = red\rpush rkey(hash, 'useragent'), ngx.var.http_user_agent or ""
  ok, err = red\rpush rkey(hash, 'visitor'), ngx.var.remote_addr or ""

redirect = (hash) ->
  url, err = red\get rkey(hash, 'url')
  if not url then errexit(err)
  if url == ngx.null
    ngx.exit(404)
  visit(hash)
  ngx.redirect(url)


create = (url) ->
  hash, err = red\get "lsurl:"..url
  if not hash then errexit(err)
  -- Check for already erxisting
  if hash == ngx.null then
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
    -- Set salt using set $lsurlsalt "mysalt" in nginx.conf
    h = hashids.new(ngx.var.lsurlsalt, 0, alphabet)
    count, err = red\incr 'lsurl:count'
    if not count then errexit(err)
    hash = h\encode(count)
    ok, err = red\set "lsurl:"..url, hash
    ok, err = red\set rkey(hash, 'url'), url

  visit(hash)
  ngx.header.content_type = 'application/json; charset=UTF-8'
  ngx.print cjson.encode
    url: "#{ngx.var.scheme}://#{ngx.var.host}/+#{hash}"
  ngx.exit(200)

method =  ngx.req.get_method!
if method == 'GET'
  if ngx.var.uri\sub(2, 2) == '+'
    hash = ngx.var.uri\sub(3)
    return redirect(hash)

  args = ngx.req.get_uri_args!
  if args.url and args.url != ''
    return create(args.url)

ngx.exit(404)




