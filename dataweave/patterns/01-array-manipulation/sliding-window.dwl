/**
 * Pattern: Sliding Window
 * Category: Array Manipulation
 * Difficulty: Advanced
 * Description: Create overlapping windows (sub-arrays) of a fixed size
 * that slide across an array. Used for time-series analysis, moving
 * averages, streak detection, and sequential pattern matching.
 *
 * Input (application/json):
 * {
 *   "prices": [
 *     100,
 *     102,
 *     98,
 *     105,
 *     110,
 *     108,
 *     115
 *   ],
 *   "windowSize": 3
 * }
 *
 * Output (application/json):
 * {
 * "windows": [
 * [100, 102, 98],
 * [102, 98, 105],
 * [98, 105, 110],
 * [105, 110, 108],
 * [110, 108, 115],
 * [108, 115, 120],
 * [115, 120, 118],
 * [120, 118, 125]
 * ],
 * "movingAverages": [100.0, 101.67, 104.33, 107.67, 109.33, 110.33, 117.67, 119.33, 121.0],
 * "maxInWindow": [102, 105, 110, 110, 115, 120, 120, 125]
 * }
 */
%dw 2.0
output application/json
var prices = payload.prices
var windowSize = payload.windowSize
fun slidingWindow(arr, size) = (0 to (sizeOf(arr) - size)) map (i) -> arr[i to (i + size - 1)]
var windows = slidingWindow(prices, windowSize)
---
{windows: windows, movingAverages: windows map (w) -> round(avg(w) * 100) / 100, maxInWindow: windows map (w) -> max(w)}
