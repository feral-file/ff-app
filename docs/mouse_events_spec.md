# FF1 interact: relayer commands and `request` data

Each call uses HTTP body `{ "command": "<name>", "request": { ... } }` (`FF1WifiRestClient.sendCommand`).

**Extensions (new FF1, optional):** keep the same `command` strings; add keys only inside `request`. Old FF1 should ignore unknown keys.

**Pointer position:** Do **not** send absolute coordinates (`x`, `y`) in these commands. The **player** applies pointer gestures at the **current synthetic mouse position** (it maintains cursor state). `dragGesture` and `clickAndDragGesture` update that position with `dx` / `dy`; discrete pointer commands use the cursor as-is.

---

## 1. Client recognition (`FfMouseGestureDetector`)

The mobile touchpad uses Flutter’s **`TapAndPanGestureRecognizer`** (touch only). It exposes:

| Callback        | When it runs |
| --------------- | ------------ |
| `onTap`         | **Single tap** — first tap in a series; `onTap` is deferred until Flutter’s `kDoubleTapTimeout` so a second tap in time can become a double-tap instead of two singles. |
| `onDoubleTap`   | **Double-click (discrete)** — user completes **two tap-ups in place** in the double-tap window (second `TapDragUp` has `consecutiveTapCount == 2`). The user **lifts the finger** after the second tap; no drag. |
| `onMove`        | **Move-only pan** — a drag where **`onDragStart` has `consecutiveTapCount == 1`**: one finger down, then movement past pan slop (like moving the cursor without a prior “second tap hold”). |
| `onClickAndDrag` | **Double-tap-hold then drag (click-and-drag)** — a drag where **`onDragStart` has `consecutiveTapCount == 2`**: user has already done a first tap, **second contact** is part of the same consecutive-tap series, and the user **holds and drags** (does not release for a second quick tap). Same pattern as *double-tap to drag* on many laptop trackpads. |
| `onLongPress`   | **`LongPressGestureRecognizer`** won the arena; drag/tap for that contact is cancelled. |

**Important:** `onDoubleTap` and `onClickAndDrag` are **mutually exclusive** for the same second tap: if the user drags, the second tap does **not** complete as a double-tap *up* → `onDoubleTap` is not called; the gesture is classified as `onClickAndDrag` after drag starts.

---

## 2. FF1 / relayer mapping (example: `TouchPad`)

Discrete clicks map 1:1 to gesture commands. Drags are batched with `dx` / `dy` in `cursorOffsets` (2 decimal places in wire form).

| UI callback / path | Relayer pattern |
| ------------------ | --------------- |
| `onTap` | `tapGesture` |
| `onDoubleTap` | `doubleTapGesture` (double-click only) |
| `onLongPress` | `longPressGesture` |
| `onMove` | Batched `dragGesture` with `cursorOffsets` (move-only / pan) via the app’s `drag` control call. |
| `onClickAndDrag` | Batched `clickAndDragGesture` with the same `request` shape (`cursorOffsets`) via the app’s `clickAndDrag` control call. **This client does not** send a preceding `doubleTapGesture` in this path. |

---

## 3. `MouseButton`

Used in `tapGesture`, `longPressGesture`, and `doubleTapGesture` `request` objects (and may be reused for future pointer fields).

| Value    | Meaning                                               |
| -------- | ----------------------------------------------------- |
| `left`   | Primary button (**default** when `button` is omitted) |
| `right`  | Secondary button                                      |
| `middle` | Middle / auxiliary button                             |

Wire format: **string** — one of `left`, `right`, `middle` (lowercase).

---

## 4. Single gestures (wire)

### 4.1 `tapGesture`

**`request`:**

```json
{
  "button": "left"
}
```

- `button`: **string**, `MouseButton`. **Default:** `left` if omitted (`{}` means `left`).

**Player effect:** **Single click** at the current cursor for `button`.

---

### 4.2 `longPressGesture`

**`request`:**

```json
{
  "button": "left"
}
```

- `button`: **string**, `MouseButton`. **Default:** `left` if omitted (`{}` means `left`).

**Player effect:** **Long-press** at the current cursor for `button`.

---

### 4.3 `doubleTapGesture`

**`request`:**

```json
{
  "button": "left"
}
```

- `button`: **string**, `MouseButton`. **Default:** `left` if omitted (`{}` means `left`).

**Player effect:** **Double-click** at the current cursor for `button` (discrete; maps to `onDoubleTap` in **§1**).

---

### 4.4 `dragGesture` (move-only / pan)

**`request`:**

```json
{
  "cursorOffsets": [{ "dx": 1.23, "dy": -0.45 }]
}
```

- `cursorOffsets`: array of steps; each `dx` / `dy` is a **number** rounded to **2** decimal places.
- **Semantic:** Move-only pan (`onMove` in **§1** / **§2**). Primary-button drag uses **`clickAndDragGesture`** (4.5).

---

### 4.5 `clickAndDragGesture` (double-tap-hold then drag)

Same **`request`** shape and rounding rules as **`dragGesture`** (4.4); distinct **`command`** so the player can apply primary-button drag without inferring it from the same `dragGesture` name.

**`request`:** same as **§4.4** (`cursorOffsets` only).

---

### 4.6 `sendKeyboardEvent`

**`request`:**

```json
{
  "code": 97
}
```

- `code`: **int** — character code (e.g. `String.codeUnitAt(0)` from the typed character).

**Player effect:** Delivers a **keyboard** input to the focused target.
