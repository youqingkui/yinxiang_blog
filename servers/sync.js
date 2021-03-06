// Generated by CoffeeScript 1.8.0
(function() {
  var Evernote, Note, Sync, SyncStatus, Tags, async, client, eqArr, noteStore, uniq;

  Evernote = require('evernote').Evernote;

  async = require('async');

  client = require('../servers/ervernote');

  noteStore = client.getNoteStore('https://app.yinxiang.com/shard/s5/notestore');

  Note = require('../models/note');

  Tags = require('../models/tags');

  SyncStatus = require('../models/sync_status');

  uniq = require('uniq');

  eqArr = require('./help').eqArr;

  Sync = function() {
    this.guid = 'bd6d5877-9ff8-400d-9d83-f6c4baeb2406';
    this.filterNote = new Evernote.NoteFilter();
    this.filterNote.notebookGuid = this.guid;
    this.countNoteNum = 0;
    this.serverTagNames = [];
    this.needSync = false;
    this.serverSync = null;
    this.reParams = new Evernote.NotesMetadataResultSpec();
    this.reParams.includeTitle = true;
    this.reParams.includeCreated = true;
    this.reParams.includeUpdated = true;
    this.reParams.includeDeleted = true;
    this.reParams.includeTagGuids = true;
    this.reParams.includeNotebookGuid = true;
  };


  /* 检查笔记状态，确定是否需要更新 */

  Sync.prototype.checkStatus = function(cb) {
    var self;
    self = this;
    return async.auto({
      getServerStatus: function(callback) {
        return noteStore.getSyncState(function(err, info) {
          if (err) {
            return callback(err);
          }
          return callback(null, info);
        });
      },
      getDbStatusInfo: function(callback) {
        return self.getDbStatus(function(err, row) {
          if (err) {
            return callback(err);
          }
          return callback(null, row);
        });
      },
      compareStatus: [
        'getServerStatus', 'getDbStatusInfo', function(callback, result) {
          var dbInfo, serverInfo;
          serverInfo = result.getServerStatus;
          dbInfo = result.getDbStatusInfo;
          console.log("serverInfo", serverInfo);
          console.log("dbInfo", dbInfo);
          if (serverInfo.updateCount !== dbInfo.updateCount) {
            return self.updateStatus(serverInfo, dbInfo, function(err, row) {
              if (err) {
                return callback(err);
              }
              self.needSync = true;
              return callback();
            });
          } else {
            return callback();
          }
        }
      ]
    }, function(autoErr) {
      if (autoErr) {
        return cb(autoErr);
      }
      return cb();
    });
  };


  /* 更新同步状态 */

  Sync.prototype.updateStatus = function(s, d, cb) {
    d.currentTime = s.currentTime;
    d.fullSyncBefore = s.fullSyncBefore;
    d.updateCount = s.updateCount;
    d.uploaded = s.uploaded;
    return d.save(function(err, row) {
      if (err) {
        return cb(err);
      }
      return cb(null, row);
    });
  };


  /* 获取数据库同步状态 */

  Sync.prototype.getDbStatus = function(cb) {
    return SyncStatus.findOne(function(err, row) {
      var newStatus;
      if (err) {
        return cb(err);
      }
      if (!row) {
        newStatus = new SyncStatus();
        return newStatus.save(function(sErr, newStatus) {
          if (sErr) {
            return cb(sErr);
          }
          return cb(null, newStatus);
        });
      } else {
        return cb(null, row);
      }
    });
  };


  /* 得到笔记本笔记总数 */

  Sync.prototype.getNoteCount = function(cb) {
    var self;
    self = this;
    return noteStore.findNoteCounts(this.filterNote, false, function(err, info) {
      if (err) {
        return cb(err);
      } else {
        self.countNoteNum = info.notebookCounts[self.guid];
        self.page = Math.ceil(self.countNoteNum / 50);
        console.log("countNoteNum ==>", self.countNoteNum);
        console.log("page ==>", self.page);
        return cb();
      }
    });
  };


  /* 同步笔记本笔记信息 */

  Sync.prototype.syncInfo = function(offset, max, fun) {
    var self;
    self = this;
    return async.auto({
      getSimpleInfo: function(cb) {
        return noteStore.findNotesMetadata(self.filterNote, offset, max, self.reParams, function(err, info) {
          if (err) {
            return cb(err);
          }
          console.log("findNotesMetadata offset", offset);
          console.log(info);
          return cb(null, info.notes);
        });
      },
      checkNew: [
        'getSimpleInfo', function(cb, result) {
          var simpleArr;
          simpleArr = result.getSimpleInfo;
          return self.upOrCrNote(simpleArr, function(err) {
            if (err) {
              return cb(err);
            }
            return cb();
          });
        }
      ]
    }, function(autoErr) {
      if (autoErr) {
        return fun(autoErr);
      }
      console.log("in here");
      return fun();
    });
  };


  /* 创建或者更新笔记 */

  Sync.prototype.upOrCrNote = function(simpleArr, cb) {
    var self;
    self = this;
    return async.eachSeries(simpleArr, function(item, callback) {
      return Note.findOne({
        'guid': item.guid
      }, function(findErr, note) {
        if (findErr) {
          return callback(findErr);
        }
        if (!note) {
          return self.createNote(item, function(cErr, newNote) {
            if (cErr) {
              return callback(cErr);
            }
            console.log("create new note", newNote.title);
            return callback();
          });
        } else {
          return self.updateNote(note, item, function(uErr, upNote) {
            if (uErr) {
              return callback(uErr);
            }
            return callback();
          });
        }
      });
    }, function(eachErr) {
      if (eachErr) {
        return cb(eachErr);
      }
      return cb();
    });
  };


  /* 更新笔记基本、内容、标签 */

  Sync.prototype.updateNote = function(note, upInfo, cb) {
    var self;
    self = this;
    return async.auto({
      updateNoteBase: function(callback) {
        return self.updateNoteBase(note, upInfo, function(err, note1) {
          if (err) {
            return callback(err);
          }
          return callback(null, note1);
        });
      },
      updateNoteContent: [
        'updateNoteBase', function(callback, result) {
          note = result.updateNoteBase;
          return self.updateNoteContent(note, function(err, note2) {
            if (err) {
              return callback(err);
            }
            return callback(null, note2);
          });
        }
      ],
      updateNoteTagName: [
        'updateNoteContent', function(callback, result) {
          note = result.updateNoteContent;
          return self.updateNoteTagName(note, function(err, note3) {
            if (err) {
              return callback(err);
            }
            return callback(null, note3);
          });
        }
      ]
    }, function(autoErr, result) {
      if (autoErr) {
        return cb(autoErr);
      }
      return cb(null, result.updateNoteTagName);
    });
  };


  /* 更新笔记本基本信息 */

  Sync.prototype.updateNoteBase = function(note, upInfo, cb) {
    var baseUp, i, upBase, _i, _len;
    baseUp = ['title', 'created', 'updated', 'deleted', 'notebookGuid'];
    upBase = false;
    for (_i = 0, _len = baseUp.length; _i < _len; _i++) {
      i = baseUp[_i];
      if (note[i] !== upInfo[i]) {
        console.log("" + note[i] + " != " + upInfo[i]);
        note[i] = upInfo[i];
        upBase = true;
      }
    }
    if (Array.isArray(note['tagGuids']) === false || eqArr(note['tagGuids'], upInfo['tagGuids']) === false) {
      note['tagGuids'] = upInfo['tagGuids'];
      upBase = true;
    }
    if (upBase) {
      return note.save(function(err, row) {
        if (err) {
          return cb(err);
        }
        console.log("笔记 => " + note.title + " 更改了基本信息");
        return cb(null, row);
      });
    } else {
      console.log("笔记 => " + note.title + " 不需要更改基本信息");
      return cb(null, note);
    }
  };


  /* 更新笔记本内容 */

  Sync.prototype.updateNoteContent = function(note, cb) {
    return noteStore.getNoteContent(note.guid, function(err, content) {
      if (err) {
        return cb(err);
      }
      if (note.content !== content) {
        note.content = content;
        return note.save(function(sErr, row) {
          if (sErr) {
            return cb(sErr);
          }
          console.log("笔记 => " + row.title + " 更新了笔记内容");
          return cb(null, row);
        });
      } else {
        console.log("笔记 => " + note.title + " 内容不需要更新");
        return cb(null, note);
      }
    });
  };


  /* 更新笔记本标签名 */

  Sync.prototype.updateNoteTagName = function(note, cb) {
    var self;
    self = this;
    return noteStore.getNoteTagNames(note.guid, function(err, tagArr) {
      var i, oldTagName, _i, _len;
      if (err) {
        return cb(err);
      }
      for (_i = 0, _len = tagArr.length; _i < _len; _i++) {
        i = tagArr[_i];
        self.serverTagNames.push(i);
      }
      if (eqArr(note.tags, tagArr)) {
        console.log("笔记 => " + note.title + " 不需要更新标签 ");
        return cb(null, note);
      } else {
        oldTagName = note.tags;
        note.tags = tagArr;
        return note.save(function(sErr, row) {
          if (sErr) {
            return cb(sErr);
          }
          console.log("笔记 => " + row.title + " 标签由" + oldTagName + "  变为 ==> " + row.tags);
          return cb(null, row);
        });
      }
    });
  };


  /* 创建笔记 */

  Sync.prototype.createNote = function(simpleInfo, cb) {
    var newNote, self;
    self = this;
    newNote = new Note();
    newNote.title = simpleInfo.title;
    newNote.guid = simpleInfo.guid;
    newNote.created = simpleInfo.created;
    newNote.updated = simpleInfo.updated;
    newNote.deleted = simpleInfo.deleted;
    newNote.tagGuids = simpleInfo.tagGuids;
    newNote.notebookGuid = simpleInfo.notebookGuid;
    return newNote.save(function(sErr, note) {
      if (sErr) {
        return cb(sErr);
      }
      console.log("创建了新笔记 => " + note.title);
      return self.getNoteContent(note, function(gErr, newNote) {
        if (gErr) {
          return cb(gErr);
        }
        console.log("新笔记 " + newNote.title + " 获取内容成功");
        return self.updateNoteTagName(newNote, function(uErr, upNote) {
          if (uErr) {
            return cb(uErr);
          }
          return cb(null, upNote);
        });
      });
    });
  };


  /* 获取笔记内容 */

  Sync.prototype.getNoteContent = function(note, cb) {
    return noteStore.getNoteContent(note.guid, function(err, content) {
      if (err) {
        return cb(err);
      }
      note.content = content;
      return note.save(function(sErr, newNote) {
        if (sErr) {
          return cb(sErr);
        }
        return cb(null, newNote);
      });
    });
  };


  /* 更新笔记本标签 */

  Sync.prototype.updateNoteBookTags = function(callback) {
    var self;
    self = this;
    return async.auto({
      findDbTags: function(cb) {
        return Tags.findOne(function(err, dTag) {
          var newTags;
          if (err) {
            return cb(err);
          }
          if (!dTag) {
            newTags = new Tags();
            return newTags.save(function(sErr, nTag) {
              if (sErr) {
                return cb(sErr);
              }
              return cb(null, nTag);
            });
          } else {
            return cb(null, dTag);
          }
        });
      },
      compareTag: [
        'findDbTags', function(cb, result) {
          var dTag, oldTags;
          dTag = result.findDbTags;
          self.serverTagNames = uniq(self.serverTagNames);
          oldTags = uniq(dTag.tags);
          if (eqArr(oldTags, self.serverTagNames) === false) {
            dTag.tags = self.serverTagNames;
            return dTag.save(function(err, uTag) {
              if (err) {
                return cb(err);
              }
              console.log("笔记本标签" + oldTags + " ==> " + uTag.tags);
              return cb();
            });
          } else {
            console.log("笔记本标签不需要修改");
            return cb();
          }
        }
      ]
    }, function(autoErr) {
      if (autoErr) {
        return callback(autoErr);
      }
      return callback();
    });
  };

  module.exports = Sync;

}).call(this);

//# sourceMappingURL=sync.js.map
