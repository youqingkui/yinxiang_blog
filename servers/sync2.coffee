Evernote = require('evernote').Evernote;
async = require('async')
exec = require('child_process').exec
fs = require('fs')
client = require('../servers/ervernote')
noteStore = client.getNoteStore('https://app.yinxiang.com/shard/s5/notestore')
Note = require('../models/note')
Tags = require('../models/tags')
SyncStatus = require('../models/sync_status')
uniq = require('uniq')
cheerio = require('cheerio')
eqArr = require('./help').eqArr

MIME_TO_EXTESION_MAPPING = {
  'image/png': '.png',
  'image/jpg': '.jpg',
  'image/jpeg': '.jpg',
  'image/gif': '.gif'
}


class Sync
  constructor: () ->
    # 设置查找过滤的笔记本
    @guid = 'bd6d5877-9ff8-400d-9d83-f6c4baeb2406'
    @filterNote = new Evernote.NoteFilter()
    @filterNote.notebookGuid = @guid

    # 设置查找返回的参数
    @reParams = new Evernote.NotesMetadataResultSpec()
    @reParams.includeTitle = true
    @reParams.includeCreated = true
    @reParams.includeUpdated = true
    @reParams.includeDeleted = true
    @reParams.includeTagGuids = true
    @reParams.includeNotebookGuid = true



  syncInfo: (cb) ->
    ### 同步 ###
    self = @

    async.auto
      getNote:(callback) ->
        noteStore.findNotesMetadata self.filterNote, 0, 100,
        self.reParams, (err, info) ->
          return cb(err) if err
          console.log info.totalNotes
          console.log info.notes.length
          callback(null, info)


      upNote:['getNote', (callback, result) ->
        noteArr = result.getNote.notes
        async.eachSeries noteArr, (item, c1) ->
          Note.findOne {guid:item.guid}, (err, note) ->
            return c1(err) if err

            self.composeDo item, note, (err2) ->
              return c1(err2) if err2

              c1()

        ,(eachErr) ->
          console.log eachErr
          return cb(eachErr) if eachErr

          callback()
      ]

      upNoteBookTag:['upNote', (callback) ->
        self.compleNoteBooksTag (err) ->
          return callback(err) if err

          return "all ok!!"
          callback()
      ]


  composeDo: (item, note, cb) ->
    ### 集合操作 ###
    self = @

    if not note
      cggc = async.compose(
        self.getContent,self.getTagName,
        self.createNote)
      cggc item, self, (err2, res2) ->
        return cb(err2) if err2

        cb()

    else
      cggu = async.compose(
        self.getContent, self.getTagName,
        self.upbaseInfo)
      cggu note, item, self, (err3, res3) ->
        return cb(err3) if err3

        cb()




  createNote: (noteInfo, self, cb) ->
    ### 创建 ###
    newNote = new Note()
    newNote.guid = noteInfo.guid
    newNote.title = noteInfo.title
    newNote.content = noteInfo.content
    newNote.created = noteInfo.created
    newNote.updated = noteInfo.updated
    newNote.tagGuids = noteInfo.tagGuids
    newNote.notebookGuid = noteInfo.notebookGuid

    cb(null, newNote, self)


  getContent: (note, self, cb) ->
    ### 获取内容 ###
    noteStore.getNoteContent note.guid, (err, content) ->
      return cb(err) if err

      console.log "getContent ==>", note.title
      if note.content != content
        note.content = content
        self.changeImgHtml note, (err1, row) ->
          return cb(err1) if err1

          cb(null, row)
      else
        note.save (err2, row2) ->
          return cb(err2) if err2

          cb(null, row2)


  getTagName: (note, self, cb) ->
    ### 获取标签名 ###
    noteStore.getNoteTagNames note.guid, (err, tagsName) ->
      return cb(err) if err

      note.tags = tagsName if not eqArr note.tags, tagsName
      console.log "getTagName ==>", note.title
      cb(null, note, self)


  upbaseInfo: (note, upInfo, self, cb) ->
    ### 更新基本信息 ###
#    console.log upInfo
    for v, k of upInfo
      if v of note
        note[v] = k
#        console.log "k ==>", k
#        console.log "v ==>", v

    console.log "upbaseInfo ==>", note.title
    cb(null, note, self)

  changeImgHtml:(note, cb) ->
    ### 替换Img标签和下载资源 ###
    console.log "changeImgHtml ==>", note.title
    $ = cheerio.load(note.content)
    all_media = $('en-media')
    async.eachSeries all_media, (item, callback) ->

      hashStr = item.attribs.hash
      mimeType = item.attribs.type
      newTag = $("<img src=/images/#{hashStr + MIME_TO_EXTESION_MAPPING[mimeType]}>")
      getImgRes hashStr, mimeType, note.guid, (err) ->
        return callback(err) if err

        $(item).replaceWith(newTag)
        callback()

    ,(eachErr) ->
      return cb(eachErr) if eachErr

      # 移除内容标题和马克跟踪链接
      $("h3").remove()
      $("h2").remove()
      $("del").remove()
      note.htmlContent = $.html()
      note.save (sErr, row) ->
        return cb(sErr) if sErr

        cb(null, row)


  compleNoteBooksTag: (cb) ->
    ### 更新标签 ###
    sgg = async.compose(saveTags,getTagStr,getAllNoteTag)
    sgg (err, res) ->
      return cb(err) if err

      cb()

# 下载笔记图片
getImgRes = (hashStr, minmeType, noteGuid, cb) ->
  pyFile = __dirname + '/test.py'
  console.log pyFile
  exec "python #{pyFile} " + hashStr + ' ' + noteGuid, {maxBuffer: 1024 * 5000000},
  (err, stdout, stderr) ->
    return cb(err) if err

    writeRes = ('public/images/' + hashStr + MIME_TO_EXTESION_MAPPING[minmeType])
    img = new Buffer(stdout, 'base64')
    fs.writeFileSync writeRes, img
    cb()

# 获取数据库所有标签
getAllNoteTag = (callback) ->
  Note.find {}, 'tags':1, (err, tags) ->
    return cb(err) if err

#    console.log "getAllNoteTag ==>", tags
    callback(null, tags)

# 得到所有标签名
getTagStr = (tagArr, cb) ->
  tags = []
  async.eachSeries tagArr, (item, callback) ->
    for t in item.tags
      tags.push t

    callback()

  ,(eachErr) ->
    return cb(eachErr) if eachErr
    console.log "getTagStr ==>", tags
    cb(null, tags)

# 保存所有标签
saveTags = (tags, cb) ->
  tags = uniq tags
  console.log "saveTags ==>", tags
  Tags.findOne (err, dbTags) ->
    return cb(err) if err

    if dbTags
      dbTags.tags = tags
      dbTags.syncStatus = Date.parse(new Date())
    else
      dbTags = new Tags()
      dbTags.tags = tags
      dbTags.syncStatus = Date.parse(new Date())

    dbTags.save (err1, row) ->
      return cb(err1) if err1

      cb(null, row)



module.exports = Sync





