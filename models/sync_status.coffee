mongoose = require('./mongoose')

statusSchema = mongoose.Schema
  currentTime:Number
  fullSyncBefore:Number
  updateCount:Number
  uploaded:Number




module.exports = mongoose.model('SyncStatus', statusSchema)