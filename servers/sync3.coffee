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




  getNoteList: (cb) ->
    # 获取笔列表
    # return:
            #    { startIndex: 0,
            #    totalNotes: 67,
            #    notes:
            #      [ { guid: 'cce1f6ed-8322-42fc-9166-363abc1da9d2',
            #        title: 'CSS3选择',
            #        contentLength: null,
            #        created: 1408961044000,
            #        updated: 1409144595000,
            #        deleted: null,
            #        updateSequenceNum: null,
            #        notebookGuid: 'bd6d5877-9ff8-400d-9d83-f6c4baeb2406',
            #        tagGuids: [Object],
            #        attributes: null,
            #        largestResourceMime: null,
            #        largestResourceSize: null },
            #        { guid: 'c0945f75-f42b-4e05-b0f9-5b785d4a42ff',
            #          title: '伪类 & 伪元素',
            #          contentLength: null,
            #          created: 1409146304000,
            #          updated: 1410313159000,
            #          deleted: null,
            #          updateSequenceNum: null,
            #          notebookGuid: 'bd6d5877-9ff8-400d-9d83-f6c4baeb2406',
            #          tagGuids: [Object],
            #          attributes: null,
            #          largestResourceMime: null,
            #          largestResourceSize: null } ],
            #    stoppedWords: null,
            #    searchedWords: null,
            #    updateCount: 253683 }
    self = @
    noteStore.findNotesMetadata self.filterNote, 0, 100,
      self.reParams, (err, info) ->
        return cb(err) if err

        console.log info
        console.log info.totalNotes
        console.log info.notes.length
        console.log info.notes[0].tagGuids
        cb(null, info.notes)

  checkNote:(noteList, CB) ->
    self = @
    async.eachSeries noteList, (item, cb) ->
      async.auto
        # 获取笔记内容
        A:(callback) ->
          self.getContent(item, callback)
        # 查找数据库对应笔记
        B:(callback) ->
          self.findNote(item.guid, callback)
        # 创建活着更新笔记
        C:['A', 'B', (callback, rs) ->
          noteRow = rs.B
          newContent = rs.A
          if not noteRow
            console.log "[Create]"
            self.createNote item, newContent, callback

          else
            console.log "[Update]"
            self.updateNote noteRow, item, newContent, callback

        ]
      ,(err) ->
          return console.log err if err
          cb()
    ,(eachErr) ->
      return console.log err if eachErr
      CB()




  getContent: (note, cb) ->
    # 获取对应内容
    # note: evernote 获取的笔记对象
    console.log "getContent ==>", note.title

    noteStore.getNoteContent note.guid, (err, content) ->
      return cb(err) if err

      cb(null, content)


  findNote:(noteGuid, cb) ->
  # 从数据库查找对应guid笔记
  # noteGuid: 笔记guid
    Note.findOne {guid:noteGuid}, (err, note_row) ->
      return cb(err) if err

      cb(null, note_row)

  createNote: (noteInfo, noteContent,  cb) ->
  # 创建新的笔记到数据库
  # noteInfo
    self = @
    newNote = new Note()
    newNote.guid = noteInfo.guid
    newNote.title = noteInfo.title
    newNote.content = noteContent
    newNote.created = noteInfo.created
    newNote.updated = noteInfo.updated
    newNote.tagGuids = noteInfo.tagGuids
    newNote.notebookGuid = noteInfo.notebookGuid

    async.waterfall [

      (callback) ->
        self.getTagName newNote, callback

      (noteObj, callback) ->
        self.changeImgHtml noteObj, callback

    ]
    ,(err) ->
      return cb(err) if err
      cb()


  updateNote:(noteRow, itemNote, newContent, cb) ->
    self = @
    noteRow.title = itemNote.title
    noteRow.content = newContent
    noteRow.created = itemNote.created
    noteRow.updated = itemNote.updated
    noteRow.tagGuids = itemNote.tagGuids
    noteRow.notebookGuid = itemNote.notebookGuid

    async.waterfall [

        (callback) ->
          self.getTagName noteRow, callback

        (noteObj, callback) ->
          self.changeImgHtml noteObj, callback

      ]
    ,(err) ->
      return cb(err) if err
      cb()


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

  getTagName: (note, cb) ->
    ### 获取标签名 ###
    noteStore.getNoteTagNames note.guid, (err, tagsName) ->
      return cb(err) if err

      note.tags = tagsName if not eqArr note.tags, tagsName
      console.log "getTagName ==>", note.title
      cb(null, note)

  getAllNoteTag: (cb) ->
    tagsList = []
    Note.find {}, 'tags':1, (err, tags) ->
      return cb(err) if err

      console.log "getAllNoteTag ==>", tags
      for i in tags
        for t in i.tags
          tagsList.push t

      cb(null, tagsList)

  # 保存所有标签
  saveTags:(cb) ->
    self = @
    async.waterfall [
      (callback) ->
        self.getAllNoteTag callback


      (tags, callback) ->
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

    ]


  doTask:() ->
    self = @
    async.auto
      A:(cb) ->
        self.getNoteList(cb)

      B:['A', (cb, noteList) ->
        console.log noteList
        self.checkNote noteList.A, cb
      ]

      C:['B', (cb) ->
        self.saveTags cb
      ]




module.exports = Sync



#s = new Sync()
#s.doTask () ->
#  console.log "ok"