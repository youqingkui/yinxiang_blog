$(document).ready () ->
  urlName = location.pathname
  if urlName is '/'
    $(".main-nav a").removeClass()
    $("#home").addClass('selected').addClass('active').addClass('current')

  if urlName is '/archive'
    $(".main-nav a").removeClass()
    $("#archive").addClass('selected').addClass('active').addClass('current')
