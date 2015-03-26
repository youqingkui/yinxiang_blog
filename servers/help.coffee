exports.getLocalTime = (nS) ->
  year = new Date(parseInt(nS) * 1000).getFullYear();
  month = new Date(parseInt(nS) * 1000).getMonth() + 1;
  if month < 10
    month = '0' + month
  day = new Date(parseInt(nS) * 1000).getDate();
  if day < 10
    day = '0' + day
  time = year + '-' + month + '-' + day
  #  console.log(time);
  return time;

exports.getYear = (ns) ->
  year = new Date(parseInt(ns)).getFullYear()
  return year

exports.toInt = (num) ->
  if Number(num) is Math.round(num)
    return Number(num)

  else
    return 0

exports.eqArr = (arr1, arr2) ->
  arr1 = arr1.sort()
  arr2 = arr2.sort()
  return arr1.toString() is arr2.toString()

