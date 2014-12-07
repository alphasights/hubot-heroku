# Description:
#   Exposes Heroku commands to hubot
#
# Dependencies:
#   "heroku-client": "^1.9.0"
#
# Configuration:
#   HUBOT_HEROKU_API_KEY
#
# Commands:
#   hubot heroku releases <app> - Latest 10 releases
#   hubot heroku rollback <app> <version> - Rollback to a release
#   hubot heroku restart <app> - Restarts the app
#   hubot heroku migrate <app> - Runs migrations. Remember to restart the app =)
#   hubot heroku config:set <app> <KEY=value> - Set KEY to value. Overrides present key
#   hubot heroku config:unset <app> <KEY> - Unsets KEY, does not throw error if key is not present
#
# Notes:
#   Very alpha
#
# Author:
#   daemonsy

Heroku = require('heroku-client')
heroku = new Heroku(token: process.env.HUBOT_HEROKU_API_KEY)
_      = require('lodash')


module.exports = (robot) ->
  respondToUser = (robotMessage, error, successMessage) ->
    if error
      robotMessage.reply "Shucks. An error occurred. #{error.statusCode} - #{error.body.message}"
    else
      robotMessage.reply successMessage

  # Releases
  robot.respond /heroku releases (.*)$/i, (msg) ->
    appName= msg.match[1]

    msg.reply "Getting releases for #{appName}"

    heroku.apps(appName).releases().list (error, releases) ->
      output = []
      if releases
        output.push "Recent releases of #{appName}"

        for release in releases.sort((a, b) -> b.version - a.version)[0..9]
          output.push "v#{release.version} - #{release.description} - #{release.user.email} -  #{release.created_at}"

      respondToUser(msg, error, output.join("\n"))

  # Rollback
  robot.respond /heroku rollback (.*) (.*)$/i, (msg) ->
    appName = msg.match[1]
    version = msg.match[2]

    if version.match(/v\d+$/)
      msg.reply "Telling Heroku to rollback to #{version}"

      app = heroku.apps(appName)
      app.releases().list (error, releases) ->
        release = _.find releases, (release) ->
          "v#{release.version}" ==  version

        return msg.reply "Version #{version} not found for #{appName} :(" unless release

        app.releases().rollback release: release.id, (error, release) ->
          respondToUser(msg, error, "Success! v#{release.version} -> Rollback to #{version}")

  # Restart
  robot.respond /heroku restart (.*)/i, (msg) ->
    appName = msg.match[1]

    msg.reply "Telling Heroku to restart #{appName}"

    heroku.apps(appName).dynos().restartAll (error, app) ->
      respondToUser(msg, error, "Heroku: Restarting #{appName}")

  # Migration
  robot.respond /heroku migrate (.*)/i, (msg) ->
    appName = msg.match[1]

    msg.reply "Telling Heroku to migrate #{appName}"

    heroku.apps(appName).dynos().create
      command: "rake db:migrate"
      size: "1X"
      attach: true
    , (error, app) ->
      respondToUser(msg, error, "Heroku: Running migrations for #{appName}")

  # Config Vars
  robot.respond /heroku config:set (.*) (\w+)=(\w+)/i, (msg) ->
    keyPair = {}
    appName = msg.match[1]
    key     = msg.match[2]
    value   = msg.match[3]

    msg.reply "Setting config #{key} => #{value}"

    keyPair[key] = value

    heroku.apps(appName).configVars().update keyPair, (error, response) ->
      respondToUser(msg, error, "Heroku: #{key} is set to #{response[key]}")

  robot.respond /heroku config:unset (.*) (\w+)$/i, (msg) ->
    keyPair = {}
    appName = msg.match[1]
    key     = msg.match[2]
    value   = msg.match[3]

    msg.reply "Unsetting config #{key}"

    keyPair[key] = null

    heroku.apps(appName).configVars().update keyPair, (error, response) ->
      respondToUser(msg, error, "Heroku: #{key} has been unset")
