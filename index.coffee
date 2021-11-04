#!/usr/bin/env coffee

util = require 'util'
got = require 'got'
Agent = require 'agentkeepalive'
{ HttpProxyAgent, HttpsProxyAgent } = require('hpagent')
dayjs = require 'dayjs'
info = require './package.json'
median = require './median'
adjust_time = require './adjust_time'


argv = require('./argv') {
  threshold: {
    alias: 't'
    describe: 'At least how many milliseconds are considered to adjust system time'
    default: 1500
    type: 'number'
  }
  set: {
    describe: 'Adjust system time if necessary'
    alias: 's'
    default: false
    type: 'boolean'
  }
  protocol: {
    describe: 'Use this protocol when no protocol is specified in the URL'
    alias: 'p'
    default: 'https'
    type: 'string'
  }
  method: {
    describe: 'HTTP method'
    alias: 'm'
    default: 'HEAD'
    type: 'string'
  }
  http2: {
    describe: 'Try to choose either HTTP/1.1 or HTTP/2 depending on the ALPN protocol'
    default: false
    type: 'boolean'
  }
  count: {
    describe: 'The number of requests for each URL'
    alias: 'c'
    default: 4
    type: 'number'
  }
  retry: {
    alias: 'r'
    default: 0
    type: 'number'
  }
  redirect: {
    describe: 'If redirect responses should be followed'
    alias: 'R'
    default: false
    type: 'boolean'
  }
  timeout: {
    alias: 'T'
    default: 6000
    type: 'number'
  }
  insecure: {
    describe: 'Allow insecure server connections when using https'
    alias: 'k'
    default: false
    type: 'boolean'
  }
  command: {
    describe: 'Command to adjust system time, in https://day.js.org/ UTC format'
    alias: 'C'
    default: adjust_time.command
    type: 'string'
  }
  interval: {
    describe: 'The minimum milliseconds between requests'
    alias: 'i'
    default: 500
    type: 'number'
  }
  'user-agent': {
    alias: 'u'
    type: 'string'
  }
  verbose: {
    describe: 'Make the operation more talkative'
    alias: 'v'
    default: false
    type: 'boolean'
  }
}
adjust_time.command = argv.command

agent_opt = {
  keepAlive: true,
  keepAliveMsecs: 60000,
  maxSockets: 1,
}
proxy = (process.env.http_proxy or process.env.https_proxy or '').trim()
agent = if proxy is ''
  {
    http:  new Agent agent_opt
    https: new Agent.HttpsAgent agent_opt
  }
else
  agent_opt = {
    agent_opt...
    freeSocketTimeout: 30000
    proxy
  }
  {
    http:  new HttpProxyAgent  agent_opt
    https: new HttpsProxyAgent agent_opt
  }

req_opt = {
  method: argv.method.trim().toUpperCase()
  followRedirect: argv.redirect
  timeout: argv.timeout
  retry: 0
  dnsCache: true
  cache: false
  agent
  headers: {
    'user-agent': argv['user-agent']
  }
  https: {
    rejectUnauthorized: not argv.insecure
  }
  http2: argv.http2
}

client = got.extend {}
get_server_time = (url) ->
  try
    return await client url, req_opt
  catch e
    return e.response if e.response?.timings?
    throw e


get_time_delta = (url) ->
  if not /^https?:\/\//.test url
    url = "#{argv.protocol}://#{url}"
  console.log "#{argv.method} #{url}"
  for i in [1 .. argv.count]
    step = "\##{i}: ".padStart 8
    for retry in [0 .. argv.retry]
      start_at = Date.now()
      try
        r = await get_server_time url
        server_moment = + dayjs r.headers.date
      catch e
        console.log "#{step}#{e}"
      await delay argv.interval + start_at - Date.now()
      if r?.timings? and server_moment?
        break
    continue if not server_moment?
    if not r.timings.secureConnect?
      upload_at = r.timings.connect
    else
      upload_at = r.timings.secureConnect
    duration = r.timings.response - upload_at
    delta = Math.round(server_moment - r.timings.response - duration / 2) + 500
    delta_text = "#{if delta > 0 then '+' else ''}#{delta} ms".padStart 10
    if not argv.verbose
      console.log "#{step}#{delta_text}"
    else
      details = "  DNS:" + "#{r.timings.phases.dns}".padStart 5
      details += " TCP:" +  "#{r.timings.phases.tcp}".padStart 5
      details += " TSL:" + "#{if r.timings.phases.tls? then r.timings.phases.tls else '-'}".padStart 5
      details += " Send:" + "#{r.timings.upload - upload_at}".padStart 5
      details += " Recv:" + "#{r.timings.response - r.timings.upload}".padStart 5
      console.log "#{step}#{delta_text}#{details}"
    delta


delay = util.promisify (ms, cb) ->
  return cb() if ms <= 0
  setTimeout cb, ms


do ->
  if proxy isnt ''
    msg = ''
    if argv.http2
      msg = ", http2 is disabled because the agent library currently used does not support this protocol"
      delete req_opt.http2
    console.debug "Using explicit proxy server #{proxy}#{msg}"
  values = []
  for url in argv._
    values.push (await get_time_delta url)...
  if values.length is 0
    console.log "Network failure"
    process.exit 2
    return
  delta = median values
  console.log "Median: " + "#{delta} ms".padStart 10
  return if not argv.set
  if Math.abs(delta) < argv.threshold
    console.log "There is no need to adjust the time"
    return
  await adjust_time delta
