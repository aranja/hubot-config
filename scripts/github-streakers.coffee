# Description:
#   A way to interact with the Github contributions API.
#
# Commands:
#   hubot github add <github username> for <name> - Add a user.
#   hubot github remove <name> - Add a user.
#   hubot github streakers - Show the current streakers.
CronJob = require('cron').CronJob
cheerio = require('cheerio')
rsvp = require('rsvp')

module.exports = (robot) ->
  streakers = robot.brain.get('streakers') || {}

  getStreak = (name, username) ->
    return new rsvp.Promise (resolve, reject) ->
      robot.http("https://github.com/#{username}")
        .get() (error, response, body) ->
          if error or response.statusCode != 200
            reject error
            return

          $ = cheerio.load(body)
          count = $('#contributions-calendar .contrib-column:last-child .contrib-number').text().split(' ')[0]
          resolve { name, count }

  showStreaks = (username, msg) ->
    streakRequests = []

    for name, username of streakers
      streakRequests.push getStreak(name, username)

    rsvp.all(streakRequests).then (data) ->
      sorted = data.sort (a, b) -> a.count > b.count
      
      text = 'Streakers:\n'
      sorted.map (item, index) ->
        text += "#{index + 1}. @#{item.name} has a #{item.count} day(s) streak\n"

      if msg
        msg.send text
      else
        robot.messageRoom '#streakers', text
        

  robot.respond /github add @?([\w .\-]+)\?* for @?([\w .\-]+)\?*$/i, (msg) ->
    name = msg.match[2].trim()
    username = msg.match[1].trim()

    user = robot.brain.userForName(name)
    if not user
      msg.send '#{name}? Never heard of \'em'
      return

    streakers[user.name] = username
    robot.brain.set 'streakers', streakers

  robot.respond /github remove @?([\w .\-]+)\?*$/i, (msg) ->
    name = msg.match[2].trim()
    username = msg.match[1].trim()

    user = robot.brain.userForName(name)
    if not user
      msg.send "#{name}? Never heard of 'em"
      return

    delete streakers[user.name]
    robot.brain.set 'streakers', streakers

  robot.respond /github streakers$/i, (msg) ->
    showStreaks msg

  job = new CronJob
    cronTime: '00 00 10 * * *'
    onTick: showStreaks
    start: false
    timeZone: 'Atlantic/Reykjavik'

