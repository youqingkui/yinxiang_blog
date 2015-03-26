mongoose = require('./mongoose')

syncInfoSchema = mongoose.Schema
  syncStatus:Number




module.exports = mongoose.model('syncInfo', syncInfoSchema)