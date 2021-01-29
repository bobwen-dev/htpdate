#!/usr/bin/env coffee

util = require 'util'
got = require 'got'
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
    describe: 'Allow insecure server connections when using SSL'
    alias: 'k'
    default: false
    type: 'boolean'
  }
  command: {
    describe: 'Command to adjust system time, in https://day.js.org/ display format'
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
    default: "#{info.name}/#{info.version}"
    type: 'string'
  }
}
adjust_time.command = argv.command


req_opt = {
  method: argv.method.trim().toUpperCase()
  followRedirect: argv.redirect
  timeout: argv.timeout
  retry: 0
  dnsCache: true
  cache: false
  headers: {
    'user-agent': argv['user-agent']
  }
  https: {
    rejectUnauthorized: not argv.insecure
  }
}


get_server_time = (url) ->
  try
    return await got url, req_opt
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
    duration = r.timings.response - r.timings.upload
    delta = Math.round(server_moment - r.timings.end - duration / 2 + 500)
    console.log "#{step}" + "#{if delta > 0 then '+' else ''}#{delta} ms".padStart 10
    delta


delay = util.promisify (ms, cb) ->
  return cb() if ms <= 0
  setTimeout cb, ms


do ->
  proxy = process.env.http_proxy or process.env.https_proxy
  if proxy not in [undefined, ''] 
    console.debug "Using explicit proxy server #{proxy}"
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
