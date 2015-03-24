config = require('../config.json')
Evernote = require('evernote').Evernote
developerToken = process.env.DeveloperToken
console.log developerToken
client = new Evernote.Client({
  token:developerToken
})

module.exports = client

