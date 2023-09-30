// Description:
//   Exposes Heroku commands to hubot
//
// Dependencies:
//   "heroku-client": "^1.9.0"
//   "hubot-auth": "^1.2.0"
//
// Configuration:
//   HUBOT_HEROKU_API_KEY
//
// Commands:
//   hubot heroku list apps <app name filter> - Lists all apps or filtered by the name
//   hubot heroku info <app> - Returns useful information about the app
//   hubot heroku dynos <app> - Lists all dynos and their status
//   hubot heroku releases <app> - Latest 10 releases
//   hubot heroku rollback <app> <version> - Rollback to a release
//   hubot heroku restart <app> <dyno> - Restarts the specified app or dyno/s (e.g. worker or web.2)
//   hubot heroku migrate <app> - Runs migrations. Remember to restart the app =)
//   hubot heroku config <app> - Get config keys for the app. Values not given for security
//   hubot heroku config:set <app> <KEY=value> - Set KEY to value. Case sensitive and overrides present key
//   hubot heroku config:unset <app> <KEY> - Unsets KEY, does not throw error if key is not present
//   hubot heroku run <command> <app> <task> - Runs a one off task. Only rake and thor is allowed currently
//   hubot heroku ps:scale <app> <type>=<size>(:<quantity>) - Scales dyno quantity up or down
//
// Author:
//   daemonsy

const Heroku = require('heroku-client');
const objectToMessage = require("../object-to-message");
const responder = require("../responder");
const commandsWhitelist = require("../values/commands-whitelist");

let heroku = new Heroku({ token: process.env.HUBOT_HEROKU_API_KEY });
const _ = require('lodash');
const moment = require('moment');
let useAuth = (process.env.HUBOT_HEROKU_USE_AUTH || '').trim().toLowerCase() === 'true';

module.exports = function(robot) {
  let auth = function(msg, appName) {
    let hasRole, role;
    if (appName) {
      role = `heroku-${appName}`;
      hasRole = robot.auth.hasRole(msg.envelope.user, role);
    }

    let isAdmin = robot.auth.hasRole(msg.envelope.user, 'admin');

    if (useAuth && !(hasRole || isAdmin)) {
      responder(msg).say(`Access denied. You must have this role to use this command: ${role}`);
      return false;
    }
    return true;
  };

  let respondToUser = function(robotMessage, error, successMessage) {
    if (error) {
      console.log("There is error!", error);
      return robotMessage.reply(`Shucks. An error occurred. ${error.statusCode} - ${error.body.message}`);
    } else {
      return robotMessage.reply(successMessage);
    }
  };

  // App List
  // Run <command> <task> <app>
  robot.respond(/heroku run (\w+) (.+) (?:--app .+|(.+)$)/i, function(msg) {
    let command = msg.match[1].toLowerCase();
    let task = msg.match[2].replace("--app", "").trim();
    let appName = msg.match[3];

    if (!commandsWhitelist.includes(command)) { return responder(msg).say("only rake and thor is supported"); }
    if (!auth(msg, appName)) { return; }

    responder(msg).say("Dumbot will soon be deprecated. Check the docs about how to run thor tasks with Spinnaker: https://alphasights.atlassian.net/wiki/spaces/PE/pages/122323732/How+to+run+thor+tasks");

    responder(msg).say(`Telling Heroku to run \`${command} ${task}\` on ${appName}`);

    heroku.post(`/apps/${appName}/dynos`, {
      body: {
        command: `bin/procfile-wrapper.sh ${command} ${task}`,
        attach: false
      }
    }).then(dyno => {
      responder(msg).say(`Heroku: Running \`${command} ${task}\` for ${appName}`);

      return heroku.post(`/apps/${appName}/log-sessions`, {
        body: {
          dyno: dyno.name,
          tail: true
        }
      })
    }).then(session => responder(msg).say(`View logs at: ${session.logplex_url}`));
  });
};
