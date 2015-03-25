mongoose = require('./mongoose')

tasgSchema = mongoose.Schema
  tags:Array




module.exports = mongoose.model('Tags', tasgSchema)