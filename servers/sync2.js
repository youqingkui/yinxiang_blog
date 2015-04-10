// Generated by CoffeeScript 1.8.0
(function() {
  var Evernote, MIME_TO_EXTESION_MAPPING, Note, SyncStatus, Tags, async, cheerio, client, eqArr, exec, fs, getAllNoteTag, getImgRes, getTagStr, noteStore, saveTags, sync, uniq;

  Evernote = require('evernote').Evernote;

  async = require('async');

  exec = require('child_process').exec;

  fs = require('fs');

  client = require('../servers/ervernote');

  noteStore = client.getNoteStore('https://app.yinxiang.com/shard/s5/notestore');

  Note = require('../models/note');

  Tags = require('../models/tags');

  SyncStatus = require('../models/sync_status');

  uniq = require('uniq');

  cheerio = require('cheerio');

  eqArr = require('./help').eqArr;

  MIME_TO_EXTESION_MAPPING = {
    'image/png': '.png',
    'image/jpg': '.jpg',
    'image/jpeg': '.jpg',
    'image/gif': '.gif'
  };

  sync = (function() {
    function sync() {
      this.guid = 'bd6d5877-9ff8-400d-9d83-f6c4baeb2406';
      this.filterNote = new Evernote.NoteFilter();
      this.filterNote.notebookGuid = this.guid;
      this.reParams = new Evernote.NotesMetadataResultSpec();
      this.reParams.includeTitle = true;
      this.reParams.includeCreated = true;
      this.reParams.includeUpdated = true;
      this.reParams.includeDeleted = true;
      this.reParams.includeTagGuids = true;
      this.reParams.includeNotebookGuid = true;
    }

    sync.prototype.syncInfo = function(cb) {
      var self;
      self = this;
      return async.auto({
        getNote: function(callback) {
          return noteStore.findNotesMetadata(self.filterNote, 0, 100, self.reParams, function(err, info) {
            if (err) {
              return cb(err);
            }
            console.log(info.totalNotes);
            console.log(info.notes.length);
            return callback(null, info);
          });
        },
        upNote: [
          'getNote', function(callback, result) {
            var noteArr;
            noteArr = result.getNote.notes;
            return async.eachSeries(noteArr, function(item, c1) {
              return Note.findOne({
                guid: item.guid
              }, function(err, note) {
                if (err) {
                  return c1(err);
                }
                return self.composeDo(item, note, function(err2) {
                  if (err2) {
                    return c1(err2);
                  }
                  return c1();
                });
              });
            }, function(eachErr) {
              console.log(eachErr);
              if (eachErr) {
                return cb(eachErr);
              }
              return callback();
            });
          }
        ],
        upNoteBookTag: [
          'upNote', function(callback) {
            return self.compleNoteBooksTag(function(err) {
              if (err) {
                return callback(err);
              }
              return "all ok!!";
              return callback();
            });
          }
        ]
      });
    };

    sync.prototype.composeDo = function(item, note, cb) {
      var cggc, cggu, self;
      self = this;
      if (!note) {
        cggc = async.compose(self.changeImgHtml, self.getTagName, self.getContent, self.createNote);
        return cggc(item, function(err2, res2) {
          if (err2) {
            return cb(err2);
          }
          return cb();
        });
      } else {
        cggu = async.compose(self.changeImgHtml, self.getTagName, self.getContent, self.upbaseInfo);
        return cggu(note, item, function(err3, res3) {
          if (err3) {
            return cb(err3);
          }
          return cb();
        });
      }
    };

    sync.prototype.createNote = function(noteInfo, cb) {
      var newNote;
      newNote = new Note();
      newNote.guid = noteInfo.guid;
      newNote.title = noteInfo.title;
      newNote.content = noteInfo.content;
      newNote.created = noteInfo.created;
      newNote.updated = noteInfo.updated;
      newNote.tagGuids = noteInfo.tagGuids;
      newNote.notebookGuid = noteInfo.notebookGuid;
      return cb(null, newNote);
    };

    sync.prototype.getContent = function(note, cb) {
      return noteStore.getNoteContent(note.guid, function(err, content) {
        if (err) {
          return cb(err);
        }
        if (note.content !== content) {
          note.content = content;
        }
        console.log("getContent ==>", note.title);
        return cb(null, note);
      });
    };

    sync.prototype.getTagName = function(note, cb) {
      return noteStore.getNoteTagNames(note.guid, function(err, tagsName) {
        if (err) {
          return cb(err);
        }
        if (!eqArr(note.tags, tagsName)) {
          note.tags = tagsName;
        }
        console.log("getTagName ==>", note.title);
        return cb(null, note);
      });
    };

    sync.prototype.upbaseInfo = function(note, upInfo, cb) {
      var k, v;
      for (v in upInfo) {
        k = upInfo[v];
        note[k] = v;
      }
      console.log("upbaseInfo ==>", note.title);
      return cb(null, note);
    };

    sync.prototype.changeImgHtml = function(note, cb) {
      var $, all_media;
      console.log("changeImgHtml ==>", note.title);
      $ = cheerio.load(note.content);
      all_media = $('en-media');
      return async.eachSeries(all_media, function(item, callback) {
        var hashStr, mimeType, newTag;
        hashStr = item.attribs.hash;
        mimeType = item.attribs.type;
        newTag = $("<img src=/images/" + (hashStr + MIME_TO_EXTESION_MAPPING[mimeType]) + ">");
        return getImgRes(hashStr, mimeType, note.guid, function(err) {
          if (err) {
            return callback(err);
          }
          $(item).replaceWith(newTag);
          return callback();
        });
      }, function(eachErr) {
        if (eachErr) {
          return cb(eachErr);
        }
        note.htmlContent = $.html();
        return note.save(function(sErr, row) {
          if (sErr) {
            return cb(sErr);
          }
          return cb(null, row);
        });
      });
    };

    sync.prototype.compleNoteBooksTag = function(cb) {
      var sgg;
      sgg = async.compose(saveTags, getTagStr, getAllNoteTag);
      return sgg(function(err, res) {
        if (err) {
          return cb(err);
        }
        return cb();
      });
    };

    return sync;

  })();

  getImgRes = function(hashStr, minmeType, noteGuid, cb) {
    var pyFile;
    pyFile = __dirname + '/test.py';
    console.log(pyFile);
    return exec(("python " + pyFile + " ") + hashStr + ' ' + noteGuid, {
      maxBuffer: 1024 * 50000
    }, function(err, stdout, stderr) {
      var img, writeRes;
      if (err) {
        return cb(err);
      }
      writeRes = fs.createWriteStream('public/images/' + hashStr + MIME_TO_EXTESION_MAPPING[minmeType]);
      img = new Buffer(stdout, 'base64');
      writeRes.write(img);
      return cb();
    });
  };

  getAllNoteTag = function(callback) {
    return Note.find({}, {
      'tags': 1
    }, function(err, tags) {
      if (err) {
        return cb(err);
      }
      console.log("getAllNoteTag ==>", tags);
      return callback(null, tags);
    });
  };

  getTagStr = function(tagArr, cb) {
    var tags;
    tags = [];
    return async.eachSeries(tagArr, function(item, callback) {
      var t, _i, _len, _ref;
      _ref = item.tags;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        t = _ref[_i];
        tags.push(t);
      }
      return callback();
    }, function(eachErr) {
      if (eachErr) {
        return cb(eachErr);
      }
      console.log("getTagStr ==>", tags);
      return cb(null, tags);
    });
  };

  saveTags = function(tags, cb) {
    tags = uniq(tags);
    console.log("saveTags ==>", tags);
    return Tags.findOne(function(err, dbTags) {
      if (err) {
        return cb(err);
      }
      if (dbTags) {
        dbTags.tags = tags;
        dbTags.syncStatus = Date.parse(new Date());
      } else {
        dbTags = new Tags();
        dbTags.tags = tags;
        dbTags.syncStatus = Date.parse(new Date());
      }
      return dbTags.save(function(err1, row) {
        if (err1) {
          return cb(err1);
        }
        return cb(null, row);
      });
    });
  };

  module.exports = sync;

}).call(this);

//# sourceMappingURL=sync2.js.map
