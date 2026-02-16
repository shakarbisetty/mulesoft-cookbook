%dw 2.0
import * from dw::core::Strings
import * from dw::core::Arrays

/**
 * Module: StringUtils
 * Version: 1.0.0
 *
 * Reusable string utility functions for DataWeave 2.x.
 * Import with: import modules::StringUtils
 *
 * Functions (15):
 *   camelize, snakeCase, titleCase, truncate, padLeft, padRight,
 *   slugify, mask, isBlank, isEmail, isNumeric, capitalize,
 *   removeWhitespace, reverse, countOccurrences
 */

/**
 * Convert snake_case or kebab-case to camelCase.
 * "hello_world" -> "helloWorld"
 * "foo-bar-baz" -> "fooBarBaz"
 */
fun camelize(s: String): String =
    do {
        var parts = s splitBy /[_\-\s]+/
        var head = lower(parts[0] default "")
        var tail = (parts drop 1) map ((p) ->
            upper(p[0] default "") ++ lower(p[1 to -1] default "")
        )
        ---
        head ++ (tail joinBy "")
    }

/**
 * Convert camelCase or PascalCase to snake_case.
 * "helloWorld" -> "hello_world"
 * "HTMLParser" -> "html_parser"
 */
fun snakeCase(s: String): String =
    s replace /([a-z0-9])([A-Z])/ with "$1_$2"
      replace /([A-Z]+)([A-Z][a-z])/ with "$1_$2"
      then lower($)

/**
 * Convert string to Title Case.
 * "hello world" -> "Hello World"
 * "the quick brown fox" -> "The Quick Brown Fox"
 */
fun titleCase(s: String): String =
    (s splitBy /\s+/) map ((word) ->
        upper(word[0] default "") ++ lower(word[1 to -1] default "")
    ) joinBy " "

/**
 * Truncate string to given length, appending "..." if truncated.
 * truncate("Hello World", 8) -> "Hello..."
 * truncate("Hi", 10) -> "Hi"
 */
fun truncate(s: String, len: Number): String =
    if (sizeOf(s) <= len) s
    else (s[0 to (len - 4)]) ++ "..."

/**
 * Left-pad string to target length with given character.
 * padLeft("42", 5, "0") -> "00042"
 * padLeft("hello", 3, " ") -> "hello" (no change if already >= len)
 */
fun padLeft(s: String, len: Number, char: String): String =
    if (sizeOf(s) >= len) s
    else do {
        var padding = (1 to (len - sizeOf(s))) map char
        ---
        (padding joinBy "") ++ s
    }

/**
 * Right-pad string to target length with given character.
 * padRight("42", 5, "0") -> "42000"
 */
fun padRight(s: String, len: Number, char: String): String =
    if (sizeOf(s) >= len) s
    else do {
        var padding = (1 to (len - sizeOf(s))) map char
        ---
        s ++ (padding joinBy "")
    }

/**
 * Convert string to URL-friendly slug.
 * "Hello World!" -> "hello-world"
 * "  Foo  &  Bar  " -> "foo-bar"
 */
fun slugify(s: String): String =
    lower(trim(s))
        replace /[^a-z0-9\s\-]/ with ""
        replace /[\s]+/ with "-"
        replace /\-+/ with "-"
        replace /^\-|\-$/ with ""

/**
 * Mask a string, showing only the last N characters.
 * mask("1234567890", 4) -> "******7890"
 * mask("AB", 4) -> "AB" (no mask if string shorter than visible)
 */
fun mask(s: String, visible: Number): String =
    if (sizeOf(s) <= visible) s
    else do {
        var masked = (1 to (sizeOf(s) - visible)) map "*"
        ---
        (masked joinBy "") ++ s[(sizeOf(s) - visible) to -1]
    }

/**
 * Check if string is blank (null, empty, or only whitespace).
 * isBlank("") -> true
 * isBlank("  ") -> true
 * isBlank("hi") -> false
 */
fun isBlank(s: String): Boolean =
    s == null or trim(s) == ""

/**
 * Check if string is null or blank (null-safe version).
 */
fun isBlank(s: Null): Boolean = true

/**
 * Validate email format (basic RFC-style check).
 * isEmail("user@example.com") -> true
 * isEmail("not-an-email") -> false
 */
fun isEmail(s: String): Boolean =
    s matches /^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/

/**
 * Check if string contains only numeric characters.
 * isNumeric("12345") -> true
 * isNumeric("12.34") -> false
 * isNumeric("abc") -> false
 */
fun isNumeric(s: String): Boolean =
    s matches /^\d+$/

/**
 * Capitalize first character of string.
 * capitalize("hello") -> "Hello"
 * capitalize("HELLO") -> "HELLO"
 */
fun capitalize(s: String): String =
    if (sizeOf(s) == 0) s
    else upper(s[0]) ++ (s[1 to -1] default "")

/**
 * Remove all whitespace from string.
 * removeWhitespace("hello world") -> "helloworld"
 * removeWhitespace("  a  b  c  ") -> "abc"
 */
fun removeWhitespace(s: String): String =
    s replace /\s+/ with ""

/**
 * Reverse a string.
 * reverse("hello") -> "olleh"
 * reverse("DataWeave") -> "evaeWataD"
 */
fun reverse(s: String): String =
    do {
        var chars = s splitBy ""
        var reversed = chars[-1 to 0]
        ---
        reversed joinBy ""
    }

/**
 * Count occurrences of a substring within a string.
 * countOccurrences("banana", "an") -> 2
 * countOccurrences("hello", "xyz") -> 0
 */
fun countOccurrences(s: String, sub: String): Number =
    if (sizeOf(sub) == 0) 0
    else sizeOf(s scan sub)
