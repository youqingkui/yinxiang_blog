mongoose = require('./mongoose')
uniq = require('uniq')

noteSchema = mongoose.Schema
  guid:String
  title:String
  content:String
  created:Number
  updated:Number
  deleted:Boolean
  tagGuids:Array
  notebookGuid:String
  htmlContent:String
  tags:Array

noteSchema.methods.findSameGuid = (cb) ->
  return @.model('Note').findOne {guid:@.guid} , cb

noteSchema.methods.getAllTagName = (cb) ->
  return @.model('Note').find({}, 'tags':1).exec (err, notes) ->
    return console.log err if err
    tags = []
    for note in notes
      for t in notes.tags
        tags.push t
    return tags = uniq(tags)








module.exports = mongoose.model('Note', noteSchema)