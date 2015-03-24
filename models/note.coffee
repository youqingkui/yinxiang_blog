mongoose = require('./mongoose')

noteSchema = mongoose.Schema
  guid:String
  title:String
  content:String
  created:Number
  updated:Number
  deleted:Boolean
  tagGuids:Array
  notebookGuid:String

noteSchema.methods.findSameGuid = (cb) ->
  return @.model('Note').findOne {guid:@.guid} , cb

module.exports = mongoose.model('Note', noteSchema)