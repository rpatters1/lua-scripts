# FCMCtrlCheckbox

Summary of modifications:
- Added `CheckChange` custom control event.

## Functions

- [SetCheck(self, checked)](#setcheck)
- [HandleCheckChange(control, last_check)](#handlecheckchange)
- [AddHandleChange(self, callback)](#addhandlechange)
- [RemoveHandleCheckChange(self, callback)](#removehandlecheckchange)

### SetCheck

```lua
fcmctrlcheckbox.SetCheck(self, checked)
```

[View source](https://github.com/finale-lua/lua-scripts/tree/master/src/mixin/FCMCtrlCheckbox.lua#L26)

**[Fluid] [Override]**
Ensures that `CheckChange` event is triggered.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `self` | `FCMCtrlCheckbox` |  |
| `checked` | `number` |  |

### HandleCheckChange

```lua
fcmctrlcheckbox.HandleCheckChange(control, last_check)
```

[View source](https://github.com/finale-lua/lua-scripts/tree/master/src/mixin/FCMCtrlCheckbox.lua#L54)

**[Callback Template]**

| Input | Type | Description |
| ----- | ---- | ----------- |
| `control` | `FCMCtrlCheckbox` | The control that was changed. |
| `last_check` | `string` | The previous value of the control's check state.. |

### AddHandleChange

```lua
fcmctrlcheckbox.AddHandleChange(self, callback)
```

[View source](https://github.com/finale-lua/lua-scripts/tree/master/src/mixin/FCMCtrlCheckbox.lua#L-1)

**[Fluid]**
Adds a handler for when the value of the control's check state changes.
The even will fire when:
- The window is created (if the check state is not `0`)
- The control is checked/unchecked by the user
- The control's check state is changed programmatically (if the check state is changed within a handler, that *same* handler will not be called again for that change.)

| Input | Type | Description |
| ----- | ---- | ----------- |
| `self` | `FCMCtrlCheckbox` |  |
| `callback` | `function` | See `HandleCheckChange` for callback signature. |

### RemoveHandleCheckChange

```lua
fcmctrlcheckbox.RemoveHandleCheckChange(self, callback)
```

[View source](https://github.com/finale-lua/lua-scripts/tree/master/src/mixin/FCMCtrlCheckbox.lua#L66)

**[Fluid]**
Removes a handler added with `AddHandleCheckChange`.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `self` | `FCMCtrlCheckbox` |  |
| `callback` | `function` |  |
