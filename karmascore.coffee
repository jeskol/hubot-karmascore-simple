# Description:
#     A module to track and give karma
# Notes:
#     Very early

module.exports = (robot) ->

    karmaHelp = """```
Karma scores are tracked for each user.  You can only give as much karma as you have in your bank (separate value).  Receiving karma also adds to your karma bank.  Giving karma incurs a short cooldown to prevent spamming.
To add karma:          <user>: +<1-5>
To view a score:       hubot: score <user>
To view your bank:     hubot: karma bank
```"""

    bannedUsers = ['slackbot']
    giverCooldown = {}

    getKarmaBank = (username) ->
        karmaBank = robot.brain.get('karmaBank') or {}
        if not karmaBank.hasOwnProperty(username)
            karmaBank[username] = 5
            robot.brain.set 'karmaBank', karmaBank
        return parseInt(karmaBank[username]) or 0

    mathKarmaBank = (username, value) ->
        karmaBank = robot.brain.get('karmaBank') or {}
        current = parseInt(karmaBank[username]) or 0
        newscore = current + parseInt(value) or 0
        karmaBank[username] = newscore
        robot.brain.set 'karmaBank', karmaBank

    getKarma = (name) ->
        karmaScore = robot.brain.get('karmaScore') or {}
        return karmaScore[name] or 0

    addKarma = (giver, receiver, value) ->
        cooldown = giverCooldown[giver] * 1 or 0
        if giver != receiver and cooldown == 0
            karmaScore = robot.brain.get('karmaScore') or {}
            giverBank = getKarmaBank(giver)
            if giverBank == 0
                return 1
            if giverBank < value
                value = giverBank
            newscore = (parseInt(karmaScore[receiver]) or 0) + (parseInt(value) or 0)
            mathKarmaBank(giver, -Math.abs((parseInt(value) or 0)))
            karmaScore[receiver] = newscore
            mathKarmaBank(receiver, Math.abs((parseInt(value) or 0) + 1))
            robot.brain.set 'karmaScore', karmaScore
            delay = value * 2000 * value
            karmaCooldown(giver, delay)
            return 0
        else
            return 2

    karmaCooldown = (giver, delay) ->
        giverCooldown[giver] = 1
        setTimeout ->
            giverCooldown[giver] = 0
        , delay

    checkTransaction = (giver, receiver) ->
        approval = 1
        users = robot.brain.usersForFuzzyName(receiver)
        if (giver == receiver) or (giver in bannedUsers) or (users.length != 1)
            approval = 0
        return approval
            
    robot.hear /([a-zA-Z0-9_-]+):? \+([0-5]{1})/i, (msg) ->
        giver = msg.message.user.name
        target = msg.match[1].toLowerCase()
        users = robot.brain.usersForFuzzyName(target)
        if users.length is 1 or target == 'test'
            user = users[0]
            karmaAdd = msg.match[2]
            karmaResult = addKarma(giver, user.name, karmaAdd)
            if karmaResult == 2
                msg.send "#{giver} is on karma cooldown, try again later"
            if karmaResult == 1
                msg.reply "Your karma bank is empty"
        else
            msg.send "no user #{target}"

    robot.respond /score ([a-zA-Z0-9]+)/i, (msg) ->
        target = msg.match[1].toLowerCase()
        users = robot.brain.usersForFuzzyName(target)
        if users.length is 1
            username = users[0].name
            score = getKarma(username)
            msg.send "#{username} has #{score} karma"
        else
            msg.send "no user #{target}"

    robot.respond /karma bank/i, (msg) ->
        username = msg.message.user.name
        bank = getKarmaBank(username)
        msg.reply "You can give out up to #{bank} karma"

    robot.respond /karma help/i, (msg) ->
        msg.send "#{karmaHelp}"

    robot.respond /revolution ([a-zA-Z0-9]+)/i, (msg) ->
        giver = msg.message.user.name
        target = msg.match[1].toLowerCase()
        if checkTransaction(giver, target)
            bankValue = getKarmaBank(target)
            score = getKarma(target)
            karmaScore = robot.brain.get('karmaScore')
            karmaBank = robot.brain.get('karmaBank')
            karmaBank[target] = 5
            karmaScore[target] = 1
            msg.send "REVOLUTION! #{target} (bank #{bankValue} score #{score})"
            robot.brain.set 'karmaScore', karmaScore
            robot.brain.set 'karmaBank', karmaBank
