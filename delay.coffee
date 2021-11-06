util = require 'util'

module.exports = util.promisify (ms, cb) ->
  return cb() if ms <= 0
  setTimeout cb, ms
