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


class sync
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

#  getPageCount: (cb) ->
#    self = @
#    noteStore.findNoteCounts @filterNote, false, (err, Info) ->
#      return cb(err) if err
#
#      countNoteNum = info.notebookCounts[self.guid]
#      page = Math.ceil(countNoteNum / 50)
#      cb(null, page)

  syncInfo: (cb) ->
    self = @

    async.auto
      getNote:(callback) ->
        noteStore.findNotesMetadata self.filterNote, 0, 100,self.reParams, (err, info) ->
          return cb(err) if err

          callback(null, info)


      upNote:['getNote', (callback, result) ->
        noteArr = result.getNote.notes
        async.eachSeries noteArr, (item, c1) ->
          Note.findOne {guid:item.guid}, (err, note) ->
            return c1(err) if err

            if not note
              cggc = async.compose(
                self.changeImgHtml,self.getTagName,
                self.getContent,self.createNote)
              cggc item, (err2, res2) ->
                return c1(err2) if err2

                c1()

            else
              cggu = async.compose(
                self.changeImgHtml, self.getTagName,
                self.getContent, self.upbaseInfo
              )
              cggu note, item, (err3, res3) ->
                return c1(err3) if err3

                c1()

        ,(eachErr) ->
          console.log eachErr
          return cb(eachErr) if eachErr

          console.log "all dooo"

      ]


#  upNoteInfo: (item, cb) ->
#    self = @
#    async.auto
#      findNote:(callback) ->
#        Note.findOne guid:item.guid, (err, note) ->
#          return callback(err) if err
#
#          cb(null, note)
#
#      composeUp:(callback, result) ->
#        note = result.findNote
#        if not note
#          cggc = async.compose(
#            self.changeImgHtml,self.getTagName,
#                  self.getContent,self.createNote)
#          cggc note




  createNote: (noteInfo, cb) ->
    newNote = new Note()
    newNote.guid = noteInfo.guid
    newNote.title = noteInfo.title
    newNote.content = noteInfo.content
    newNote.created = noteInfo.created
    newNote.updated = noteInfo.updated
    newNote.tagGuids = noteInfo.tagGuids
    newNote.notebookGuid = noteInfo.notebookGuid

    cb(null, newNote)


  getContent: (note, cb) ->
    noteStore.getNoteContent note.guid, (err, content) ->
      return cb(err) if err

      note.content = content if note.content != content
      console.log "getContent ==>", note.title
      cb(null, note)


  getTagName: (note, cb) ->
    noteStore.getNoteTagNames note.guid, (err, tagsName) ->
      return cb(err) if err

      note.tags = tagsName if not eqArr note.tags, tagsName
      console.log "getTagName ==>", note.title
      cb(null, note)


  upbaseInfo: (note, upInfo, cb) ->

    for v, k of upInfo
      note[k] = v

    console.log "upbaseInfo ==>", note.title
    cb(null, note)

  changeImgHtml:(note, cb) ->
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
      console.log eachErr
      return cb(eachErr) if eachErr

      note.htmlContent = $.html()
      note.save (sErr, row) ->
        return cb(sErr) if sErr

        cb(null, row)

getImgRes = (hashStr, minmeType, noteGuid, cb) ->
  pyFile = __dirname + '/test.py'
  console.log pyFile
  exec "python #{pyFile} " + hashStr + ' ' + noteGuid, {maxBuffer: 1024 * 50000},
  (err, stdout, stderr) ->
    return cb(err) if err

    writeRes = fs.createWriteStream('public/images/' + hashStr + MIME_TO_EXTESION_MAPPING[minmeType])
    img = new Buffer(stdout, 'base64')
    writeRes.write img
    cb()









module.exports = sync













#class CreateNote
#  constructor: (@noteInfo) ->
#
#  save: (cb) ->
#    newNote = new Note()
#    newNote.guid = @noteInfo.guid
#    newNote.title = @noteInfo.title
#    newNote.content = @noteInfo.content
#    newNote.created = @noteInfo.created
#    newNote.updated = @noteInfo.updated
#    newNote.tagGuids = @noteInfo.tagGuids
#    newNote.notebookGuid = @noteInfo.notebookGuid
#    newNote.save (err, row) ->
#      return cb(err) if err
#      cb(null, row)
#
#
#class GetContent
#  constructor: (@noteInfo) ->
#    super
#
#  get: (cb) ->





