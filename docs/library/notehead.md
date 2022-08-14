# Notehead

## Functions

- [change_shape(note, shape)](#change_shape)

### change_shape

```lua
notehead.change_shape(note, shape)
```

[View source](https://github.com/finale-lua/lua-scripts/tree/master/src/library/notehead.lua#L35)

Changes the given notehead to a specified notehead descriptor string. Currently only supports "diamond".

| Input | Type | Description |
| ----- | ---- | ----------- |
| `note` | `FCNote` |  |
| `shape` | `lua string` |  |

| Return type | Description |
| ----------- | ----------- |
| `FCNoteheadMod` | the new notehead mod record created |
