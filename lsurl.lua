local cjson = require("cjson")
local redis = require("resty.redis")
local hashids = require("hashids")
local red = redis:new()
local errexit
errexit = function(err)
  ngx.log(ngx.ERR, "failed to connect: ", err)
  ngx.say('Error with database')
  return ngx.exit(500)
end
local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
  errexit(err)
end
local rkey
rkey = function(key, val)
  return 'lsurl:' .. key .. ':' .. val
end
local visit
visit = function(hash)
  ok, err = red:incr(rkey(hash, 'hits'))
  ok, err = red:rpush(rkey(hash, 'referer'), ngx.var.http_referer or "")
  ok, err = red:rpush(rkey(hash, 'useragent'), ngx.var.http_user_agent or "")
  ok, err = red:rpush(rkey(hash, 'visitor'), ngx.var.remote_addr or "")
end
local redirect
redirect = function(hash)
  local url
  url, err = red:get(rkey(hash, 'url'))
  if not url then
    errexit(err)
  end
  if url == ngx.null then
    ngx.exit(404)
  end
  visit(hash)
  return ngx.redirect(url)
end
local create
create = function(url)
  local hash
  hash, err = red:get("lsurl:" .. url)
  if not hash then
    errexit(err)
  end
  if hash == ngx.null then
    local alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
    local h = hashids.new(ngx.var.lsurlsalt, 0, alphabet)
    local count
    count, err = red:incr('lsurl:count')
    if not count then
      errexit(err)
    end
    hash = h:encode(count)
    ok, err = red:set("lsurl:" .. url, hash)
    ok, err = red:set(rkey(hash, 'url'), url)
  end
  visit(hash)
  ngx.header.content_type = 'application/json; charset=UTF-8'
  ngx.print(cjson.encode({
    url = tostring(ngx.var.scheme) .. "://" .. tostring(ngx.var.host) .. "/+" .. tostring(hash)
  }))
  return ngx.exit(200)
end
local method = ngx.req.get_method()
if method == 'GET' then
  if ngx.var.uri:sub(2, 2) == '+' then
    local hash = ngx.var.uri:sub(3)
    return redirect(hash)
  end
  local args = ngx.req.get_uri_args()
  if args.url and args.url ~= '' then
    return create(args.url)
  end
end
return ngx.exit(404)
