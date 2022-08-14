# Expression

## Functions

- [get_music_region(exp_assign)](#get_music_region)
- [get_associated_entry(exp_assign)](#get_associated_entry)
- [calc_handle_offset_for_smart_shape(exp_assign)](#calc_handle_offset_for_smart_shape)
- [calc_text_width(expression_def, expand_tags)](#calc_text_width)
- [is_for_current_part(exp_assign, current_part)](#is_for_current_part)

### get_music_region

```lua
expression.get_music_region(exp_assign)
```

[View source](https://github.com/finale-lua/lua-scripts/tree/master/src/library/expression.lua#L18)

Returns a music region corresponding to the input expression assignment.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `exp_assign` | `FCExpression` |  |

| Return type | Description |
| ----------- | ----------- |
| `FCMusicRegion` |  |

### get_associated_entry

```lua
expression.get_associated_entry(exp_assign)
```

[View source](https://github.com/finale-lua/lua-scripts/tree/master/src/library/expression.lua#L41)

Returns the note entry associated with the input expression assignment, if any.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `exp_assign` | `FCExpression` |  |

| Return type | Description |
| ----------- | ----------- |
| `FCNoteEntry` | associated entry or nil if none |

### calc_handle_offset_for_smart_shape

```lua
expression.calc_handle_offset_for_smart_shape(exp_assign)
```

[View source](https://github.com/finale-lua/lua-scripts/tree/master/src/library/expression.lua#L64)

Returns the horizontal EVPU offset for a smart shape endpoint to align exactly with the handle of the input expression, given that they both have the same EDU position.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `exp_assign` | `FCExpression` |  |

| Return type | Description |
| ----------- | ----------- |
| `number` |  |

### calc_text_width

```lua
expression.calc_text_width(expression_def, expand_tags)
```

[View source](https://github.com/finale-lua/lua-scripts/tree/master/src/library/expression.lua#L100)

Returns the text advance width of the input expression definition.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `expression_def` | `FCTextExpessionDef` |  |
| `expand_tags` (optional) | `boolean` | defaults to false, currently only supports `^value()` |

| Return type | Description |
| ----------- | ----------- |
| `number` |  |

### is_for_current_part

```lua
expression.is_for_current_part(exp_assign, current_part)
```

[View source](https://github.com/finale-lua/lua-scripts/tree/master/src/library/expression.lua#L119)

Returns true if the expression assignment is assigned to the current part or score.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `exp_assign` | `FCExpression` |  |
| `current_part` (optional) | `FCPart` | defaults to current part, but it can be supplied if the caller has already calculated it. |

| Return type | Description |
| ----------- | ----------- |
| `boolean` |  |
