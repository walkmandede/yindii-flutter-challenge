


### RES-102: Crash after leaving My orders

**Repro:** Open My orders with an active order, go back within 2 seconds.
Debug console shows ***setState() called after dispose()***.

**Root cause:** `_PickupCountdownState.initState` starts a `Timer.periodic`
but never keeps a reference to it. Therefore, when the page closes, the State is
disposed, but the timer keeps running and calls `setState` on the dead State.
The crash is the visible symptom; the real bug is the leaked timer.

**Fix:** Store the timer in a field and cancel it in `dispose()`.

**Rejected alternative:** `if (mounted) setState(() {})`. It hides the error by prevent rebuilding after the State is disposed,
but the timer would still run forever for every tile ever opened.

**Edge cases:** Handled: multiple tiles, each cancels its own timer.
Not handled: the timer still ticks after the pickup window opens. The feature ticket, `F-1` will replace this with a shared ticker.



## Time spent

| Desc | Time Spent |
|---|---|
| Setup (Flutter, Java, repo) | ~30 mins |
| RES-102 | ~10 mins |
| **Total** | **~40 mins** |

## With one more day
- TBD