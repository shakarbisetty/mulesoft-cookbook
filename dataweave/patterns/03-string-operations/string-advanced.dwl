/**
 * Pattern: Advanced String Functions Toolkit
 * Category: String Operations
 * Difficulty: Beginner
 * Description: Leverage dw::core::Strings utility functions (words, countMatches,
 * everyCharacter, first, mapString, remove, replaceAll, reverse) for text
 * processing. These functions simplify common string operations that otherwise
 * require regex or manual character iteration.
 *
 * Input (application/json):
 * {
 *   "text": "The quick brown fox",
 *   "email": "Alice@Example.COM",
 *   "code": "DW-2026-XYZ",
 *   "password": "MyP@ss0rd!"
 * }
 *
 * Output (application/json):
 * {
 * "wordCount": 9,
 * "words": ["The", "quick", "brown", "fox", "jumps", "over", "the", "lazy", "dog"],
 * "digitCount": 0,
 * "emailNormalized": "alice.chen@example.com",
 * "codeReversed": "100-ZYX-CBA-6202-WD",
 * "codeDigitsOnly": "2026001",
 * "firstFiveChars": "The q",
 * "passwordStrength": {
 * "hasUpper": true,
 * "hasLower": true,
 * "hasDigit": true,
 * "hasSpecial": true,
 * "length": 14
 * }
 * }
 */
%dw 2.0
import words, countMatches, everyCharacter, first, remove, reverse from dw::core::Strings
output application/json
var w = words(payload.text)
---
{wordCount: sizeOf(w), words: w, emailNormalized: lower(payload.email), codeReversed: reverse(payload.code), digitsOnly: remove(payload.code, /[^0-9]/), firstThree: first(payload.text, 3), passwordStrength: {hasUpper: !(everyCharacter(payload.password, (c) -> lower(c) == c)), hasDigit: countMatches(payload.password, /\d/) > 0}}
