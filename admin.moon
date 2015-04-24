--

-- Lua Short URL admin

--(c) 2015 Tor Hveem <tor@hveem.no>

-- License: MIT

--]]

cjson = require "cjson"
redis = require "resty.redis"
hashids = require "hashids" -- https://github.com/leihog/hashids.lua

{:say} = ngx

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

unless ngx.var.remote_addr\match '2a02:cc41:100f'
  ngx.exit(403)


ngx.header.content_type = 'text/html; charset=utf-8'

count, err = red\get 'lsurl:count'
if not count then errexit(err)

alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
-- Set salt using set $lsurlsalt "mysalt" in nginx.conf
h = hashids.new(ngx.var.lsurlsalt, 0, alphabet)

say '<table>'
say '<tr>'
say '<th>'
say '#'
say '</th>'
say '<th>'
say 'Hash'
say '</th>'
say '<th>'
say 'URL'
say '</th>'
say '<th>'
say 'Visitors'
say '</th>'
say '<th>'
say 'IPs'
say '</th>'
say '</tr>'
count = tonumber count
for i=1, count
  hash = h\encode i
  url, err = red\get rkey(hash, 'url')
  if not url or url == ngx.null
    url = 'N/A'
  hits, err = red\get rkey(hash, 'hits')
  unless hits then errexit(err)
  ips, err = red\lrange rkey(hash, 'visitor'), 0, count
  say '<tr>'
  say '<td>'
  say i
  say '</td>'
  say '<td>'
  say hash
  say '</td>'
  say '<td>'
  say "<a href=\"#{url}\">#{url\sub(1,30)}</a>"
  say '</td>'
  say '<td>'
  say hits
  say '</td>'
  say '<td>'
  --[say "#{ip}, " for ip in ips]
  say table.concat(ips, ', ')
  say '</td>'
  say '</tr>'

say '</table>'


