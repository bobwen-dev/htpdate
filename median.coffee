# Select the kth element in arr
quickselect = (arr, k) ->
  return arr[0] if arr.length is 1
  pivot = arr[0]
  lows = arr.filter (e) -> e < pivot
  highs = arr.filter (e) -> e > pivot
  pivots = arr.filter (e) -> e is pivot
  if k < lows.length
    # the pivot is too high
    quickselect lows, k
  else if k < lows.length + pivots.length
    # We got lucky and guessed the median
    pivot
  else
    # the pivot is too low
    quickselect highs, k - lows.length - pivots.length


module.exports = (arr) ->
  L = arr.length
  halfL = L / 2
  if (L % 2) is 1
    quickselect arr, halfL
  else
    0.5 * (quickselect(arr, halfL - 1) + quickselect(arr, halfL))
