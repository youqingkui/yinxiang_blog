// Generated by CoffeeScript 1.10.0
(function() {
  exports.getLocalTime = function(nS) {
    var day, month, time, year;
    year = new Date(parseInt(nS) * 1000).getFullYear();
    month = new Date(parseInt(nS) * 1000).getMonth() + 1;
    if (month < 10) {
      month = '0' + month;
    }
    day = new Date(parseInt(nS) * 1000).getDate();
    if (day < 10) {
      day = '0' + day;
    }
    time = year + '-' + month + '-' + day;
    return time;
  };

  exports.getYear = function(ns) {
    var year;
    year = new Date(parseInt(ns)).getFullYear();
    return year;
  };

  exports.toInt = function(num) {
    if (Number(num) === Math.round(num)) {
      return Number(num);
    } else {
      return 0;
    }
  };

  exports.eqArr = function(arr1, arr2) {
    arr1 = arr1.sort();
    arr2 = arr2.sort();
    return arr1.toString() === arr2.toString();
  };

}).call(this);

//# sourceMappingURL=help.js.map
