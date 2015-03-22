config = require('../config.json')
Evernote = require('evernote').Evernote
oauthAccessToken = process.env.oauthAccessToken

client = new Evernote.Client({token:oauthAccessToken})

module.exports = client

