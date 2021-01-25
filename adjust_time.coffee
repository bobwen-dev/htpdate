util = require 'util'
{ spawn } = require 'child_process'
dayjs = require 'dayjs'
dayjs.extend require './dayjs_format_ms'
platform = require('os').platform()


adjust_time = (delta) ->
  console.log 'Adjust time...'
  shell = spawn spawn_args...
  shell.stderr.on 'data', (data) -> console.error "> " + "#{data}".trim()
  shell.stdout.on 'data', (data) -> console.debug "> " + "#{data}".trim()
  shell.on 'close', (code) ->
    shell.stdin.end()
    console.log 'Done'
    process.exit 0
  wait_data = util.promisify (cb) ->
    shell.stdout.once 'data', (chunk) ->
      setTimeout ->
        cb null, chunk
      , 1
  input_line = util.promisify (cmd, cb) ->
    console.debug "$ #{cmd}"
    shell.stdin.write "#{cmd}\n", (p...) ->
      await wait_data() if platform in ['win32']
      cb p...
  await wait_data() if platform in ['win32']
  cmd = dayjs().add(delta, 'ms').format adjust_time.command
  await input_line cmd
  await input_line 'exit'


COMMANDS = {
  win32: '[time ]HH:mm:ss.SS[ && date ]YYYY-MM-DD'
  linux: '[date -s ]YYYY-MM-DDTHH:mm:ss.SSSZ'
}
adjust_time.command = COMMANDS[platform] or COMMANDS.linux


SHELL_ARGS = {
  win32: [
    'cmd'
    ['/q', '/k', 'prompt $H && chcp 65001 > nul']
    {
      windowsHide: true
    }
  ]
  linux: [
    'sh'
  ]
}
spawn_args = SHELL_ARGS[platform] or SHELL_ARGS.linux
if not /UTF\-8/i.test (process.env.LANGUAGE or '')
  process.env.LANGUAGE = 'C.UTF-8'


module.exports = adjust_time