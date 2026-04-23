# FF1 interact: relayer commands and `request` data

Each call uses HTTP body `{ "command": "<name>", "request": { ... } }` (`FF1WifiRestClient.sendCommand`).

**Extensions (new FF1, optional):** keep the same `command` strings; add keys only inside `request`. Old FF1 should ignore unknown keys.

**Pointer position:** Do **not** send absolute coordinates (`x`, `y`) in these commands. The **player** applies pointer gestures at the **current synthetic mouse position** (it maintains cursor state). `dragGesture` updates that position with `dx` / `dy`; discrete pointer commands use the cursor as-is.

**`dragGesture` vs click-and-drag (player semantics):**

| Client pattern | Player meaning |
| -------------- | -------------- |
| Only `dragGesture` (pan / move without a prior `doubleTapGesture` in this interaction) | **Mouse move only** — update cursor with `dx` / `dy`; primary button **not** pressed. |
| `doubleTapGesture` then `dragGesture` while the user performs a press-and-drag | **Primary-button drag** (“kéo thả”) — movement with the button **held** (click-and-drag). |

The client sends `doubleTapGesture` to **arm** drag mode; the **following** `dragGesture` stream for that touch (until release) is interpreted as dragging. A new touch that only pans should send **only** `dragGesture` so the player keeps move-only behavior.

---

## 1. `MouseButton`

Used in `tapGesture`, `longPressGesture`, and `doubleTapGesture` `request` objects (and may be reused for future pointer fields).

| Value    | Meaning                                               |
| -------- | ----------------------------------------------------- |
| `left`   | Primary button (**default** when `button` is omitted) |
| `right`  | Secondary button                                      |
| `middle` | Middle / auxiliary button                             |

Wire format: **string** — one of `left`, `right`, `middle` (lowercase).

---

## 2. Single gestures

### 2.1 `tapGesture`

**`request`:**

```json
{
  "button": "left"
}
```

- `button`: **string**, `MouseButton`. **Default:** `left` if the key is omitted (`{}` is still valid and means `left`).

**Player effect:** **Single click** at the current cursor for `button`.

---

### 2.2 `longPressGesture`

**`request`:**

```json
{
  "button": "left"
}
```

- `button`: **string**, `MouseButton`. **Default:** `left` if omitted (`{}` means `left`).

**Player effect:** **Long-press** at the current cursor for `button`.

---

### 2.3 `doubleTapGesture`

**`request`:**

```json
{
  "button": "left"
}
```

- `button`: **string**, `MouseButton`. **Default:** `left` if omitted (`{}` means `left`).

**Player effect:** **Double-click** at the current cursor for `button`, and (when followed by `dragGesture` on the same interaction) **arms** click-and-drag per the table at the top of this document.

---

### 2.4 `dragGesture` (move-only or drag deltas)

**`request`:**

```json
{
  "cursorOffsets": [{ "dx": 1.23, "dy": -0.45 }]
}
```

- `cursorOffsets`: array of steps; each `dx` / `dy` is a **number** rounded to **2** decimal places.
- Player interpretation: **move-only** vs **click-and-drag** is defined by the table at the top of this document.

---

### 2.5 `sendKeyboardEvent`

**`request`:**

```json
{
  "code": 97
}
```

- `code`: **int** — character code (e.g. `String.codeUnitAt(0)` from the typed character).

**Player effect:** Delivers a **keyboard** input to the focused target.

---

## 3. Click-and-drag (`doubleTapGesture` + `dragGesture`)

| Step | Command | Role |
| ---- | ------- | ---- |
| 3.1 | `doubleTapGesture` | **Double-click** at the current cursor **and** **arms** click-and-drag for the ongoing touch. |
| 3.2 | `dragGesture` (one or more messages) | Same `request` shape as move-only (`cursorOffsets`); player applies deltas as **primary-button drag** when armed by **3.1**. |

**Client rule:** For press-and-drag, send **3.1** then **3.2** until finger up. For pan-only, send **only** `dragGesture` (no **3.1** in that interaction) so the player uses move-only behavior.
