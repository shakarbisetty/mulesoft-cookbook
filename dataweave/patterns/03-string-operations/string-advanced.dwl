/**
 * Pattern: Advanced String Functions Toolkit
 * Category: String Operations
 * Difficulty: Beginner
 *
 * Description: Leverage dw::core::Strings utility functions (words, countMatches,
 * everyCharacter, first, mapString, remove, replaceAll, reverse) for text
 * processing. These functions simplify common string operations that otherwise
 * require regex or manual character iteration.
 *
 * Input (application/json):
 * {
 *   "text": "The quick brown fox jumps over the lazy dog",
 *   "email": "Alice.Chen@Example.COM",
 *   "code": "DW-2026-ABC-XYZ-001",
 *   "password": "MyP@ssw0rd!2026"
 * }
 *
 * Output (application/json):
 * {
 *   "wordCount": 9,
 *   "words": ["The", "quick", "brown", "fox", "jumps", "over", "the", "lazy", "dog"],
 *   "digitCount": 0,
 *   "emailNormalized": "alice.chen@example.com",
 *   "codeReversed": "100-ZYX-CBA-6202-WD",
 *   "codeDigitsOnly": "2026001",
 *   "firstFiveChars": "The q",
 *   "passwordStrength": {
 *     "hasUpper": true,
 *     "hasLower": true,
 *     "hasDigit": true,
 *     "hasSpecial": true,
 *     "length": 14
 *   }
 * }
 */
%dw 2.0
import words, countMatches, everyCharacter, first, mapString, remove, reverse from dw::core::Strings
output application/json

var w = words(payload.text)
---
{
    wordCount: sizeOf(w),
    words: w,
    digitCount: countMatches(payload.text, /\d/),
    emailNormalized: lower(payload.email),
    codeReversed: reverse(payload.code),
    codeDigitsOnly: remove(payload.code, /[^0-9]/),
    firstFiveChars: first(payload.text, 5),
    passwordStrength: {
        hasUpper: !(everyCharacter(payload.password, (c) -> lower(c) == c)),
        hasLower: !(everyCharacter(payload.password, (c) -> upper(c) == c)),
        hasDigit: countMatches(payload.password, /\d/) > 0,
        hasSpecial: countMatches(payload.password, /[^a-zA-Z0-9]/) > 0,
        length: sizeOf(payload.password)
    }
}

// Alternative 1 — mapString to ROT13 encode:
// var rot13 = mapString(payload.text, (c) ->
//     if (c >= "a" and c <= "z") String::fromCharCode((charCode(c) - 97 + 13) mod 26 + 97)
//     else c)

// Alternative 2 — word frequency counter:
// var freq = words(lower(payload.text)) reduce (w, acc = {}) ->
//     acc ++ {(w): (acc[w] default 0) + 1}

// Alternative 3 — camelCase to kebab-case:
// mapString(payload.methodName, (c) ->
//     if (upper(c) == c and c != lower(c)) "-" ++ lower(c) else c)
