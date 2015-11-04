mongoose = require('./mongoose')
uniq = require('uniq')

noteSchema = mongoose.Schema

  guid:  # 笔记guid
    type:String
    unique:true

  title:String   # 标题
  content:String # 内容
  created:Number # 创建时间
  updated:Number # 更新时间
  deleted:Boolean # 是否删除
  tagGuids:Array  # 标签guid
  notebookGuid:String # 笔记本guid
  htmlContent:String  # html内容
#  Summary:String      # 摘要，取150个字
  tags:Array          # 标签名数组

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