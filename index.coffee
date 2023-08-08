#!/usr/bin/env coffee

Agent = require 'agentkeepalive'
{ HttpProxyAgent, HttpsProxyAgent } = require('hpagent')
dayjs = require 'dayjs'
info = require './package.json'
median = require './median'
adjust_time = require './adjust_time'
delay = require './delay'


argv = null

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


client = false
get_server_time = (url, req_opt) ->
  if not client
    got = await import('got')
    client = got.default.extend {}
  abort_controller = new AbortController
  check_timer = setTimeout ->
    abort_controller.abort()
  , argv.timeout
  try
    r = await client url, {
      ...req_opt
      signal: abort_controller.signal
    }
    clearTimeout check_timer
    return r
  catch e
    clearTimeout check_timer
    return e.response if e.response?.timings?
    throw e


get_time_delta = (url, req_opt) ->
  if not /^https?:\/\//.test url
    url = "#{argv.protocol}://#{url}"
  console.log "#{argv.method} #{url}"
  for i in [1 .. argv.count]
    step = "\##{i}: ".padStart 8
    server_moment = false
    r = false
    for retry in [0 .. argv.retry]
      start_at = Date.now()
      try
        r = await get_server_time url, req_opt
        server_moment = + dayjs r.headers.date
      catch e
        message = if e.code in ['ERR_ABORTED', 'ETIMEDOUT'] then 'Timeout' else "#{e.code} #{message}"
        console.log "#{step}#{message}"
      await delay argv.interval + start_at - Date.now()
      break if server_moment
    continue if not server_moment or not r or not r.timings?
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


do ->
  argv = await require('./argv')()
  req_opt = {
    method: argv.method.trim().toUpperCase()
    followRedirect: argv.redirect
    timeout: {
      request: argv.timeout
    }
    retry: {
      limit: 0
    }
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
  if proxy isnt ''
    msg = ''
    if argv.http2
      msg = ", http2 is disabled because the agent library currently used does not support this protocol"
      delete req_opt.http2
    console.debug "Using explicit proxy server #{proxy}#{msg}"
  values = []
  for url in argv._
    values.push (await get_time_delta url, req_opt)...
  if values.length is 0
    console.log "Network failure"
    return process.exit 2
  delta = median values
  console.log "Median: " + "#{delta} ms".padStart 10
  if not argv.set
    return process.exit 0
  if Math.abs(delta) < argv.threshold
    console.log "There is no need to adjust the time"
    return process.exit 0
  await adjust_time delta, argv.command
  return process.exit 0
