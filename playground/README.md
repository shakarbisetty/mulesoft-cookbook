# DataWeave Playground

> Test and experiment with DataWeave patterns without a full Mule project.

---

## Online Playgrounds

### MuleSoft DataWeave Playground (Official)
**https://developer.mulesoft.com/learn/dataweave/**

The official browser-based DataWeave editor from MuleSoft. No install required.

- Write DW 2.0 code in the left panel
- Set input payload (JSON, XML, CSV, etc.) in the top panel
- See live output in the right panel
- Supports all MIME types and most DW modules

**Tips:**
- Use the "Input" tab to paste sample data
- Switch input MIME type with the dropdown
- Errors appear inline with line numbers
- Bookmark your transforms by saving the URL

### DataWeave Playground (Anypoint Studio)
Built into Anypoint Studio (MuleSoft's IDE):

1. Open Anypoint Studio
2. File → New → Mule Project (or use existing)
3. In the Package Explorer, right-click `src/main/resources`
4. New → File → name it `test.dwl`
5. Anypoint Studio opens the DW editor with preview

**Advantages over the web playground:**
- Access to your project's classpath (custom modules, types)
- Full autocompletion and error checking
- Integration with MUnit for automated testing

---

## How to Use These Patterns

### Quick Test (Web Playground)

1. Go to the [MuleSoft DataWeave Playground](https://developer.mulesoft.com/learn/dataweave/)
2. Open any `.dwl` file from this repo
3. Copy the **Input** section from the header comment
4. Paste it into the playground's Input panel
5. Set the Input MIME type (usually `application/json`)
6. Copy the code (everything from `%dw 2.0` to the end)
7. Paste into the Transform panel
8. Verify the output matches the **Output** section in the header comment

### In a Mule Project (Anypoint Studio)

1. Create a new Mule flow or open an existing one
2. Add a Transform Message component
3. Paste the DW code into the transform
4. Set the input metadata to match the pattern's Input type
5. Preview the output

---

## Testing Tips

- **Start with the examples as-is** — verify they produce the documented output before modifying
- **Change one thing at a time** — modify the input data incrementally to understand how the pattern behaves
- **Test edge cases:**
  - Empty arrays `[]`
  - Null fields `{"field": null}`
  - Missing fields (key not present at all)
  - Single-element arrays (especially for XML repeating elements)
  - Very large numbers, very long strings
  - Special characters in strings (`"`, `\`, `<`, `&`)
- **Use `log()` for debugging** — `log("label", value)` prints to the console and returns the value:
  ```dwl
  payload map (item) -> {
      name: log("item-name", item.name),
      total: log("total", item.price * item.quantity)
  }
  ```

---

## Useful Keyboard Shortcuts (Anypoint Studio DW Editor)

| Shortcut | Action |
|----------|--------|
| Ctrl+Space | Autocomplete |
| Ctrl+/ | Toggle comment |
| Ctrl+Shift+F | Format code |
| Ctrl+D | Delete line |
| Ctrl+Z | Undo |
| F5 | Preview output |

---

## Further Resources

| Resource | Link |
|----------|------|
| DataWeave Language Reference | [docs.mulesoft.com/dataweave](https://docs.mulesoft.com/dataweave/latest/) |
| DataWeave Function Reference | [docs.mulesoft.com/dataweave/latest/dw-functions](https://docs.mulesoft.com/dataweave/latest/dw-functions) |
| MuleSoft Training (free) | [training.mulesoft.com](https://training.mulesoft.com/) |
| MuleSoft Community Forum | [help.mulesoft.com](https://help.mulesoft.com/) |
| DataWeave Tutorial (official) | [developer.mulesoft.com/learn/dataweave](https://developer.mulesoft.com/learn/dataweave/) |

---

[Back to all patterns](../README.md)
