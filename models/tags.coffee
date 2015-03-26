mongoose = require('./mongoose')

tasgSchema = mongoose.Schema
  tags:Array
  syncStatus:Number




module.exports = mongoose.model('Tags', tasgSchema)