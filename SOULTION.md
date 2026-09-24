


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

---
 
### RES-103: Requests pile up the longer you browse
 
**Repro:** Open a deal, popping back. Then open a another and
tap "Add to bag". The console shows one `GET /deals/:id` for every deal
opened earlier, not only the current one.
 
**Root cause:** `DealDetailsController.onInit` subscribes to
`cartService.itemCount` with `ever(...)`. `CartService` is permanent, so it
holds that callback for the whole session. The route binding deletes the
controller when the page closes, but the worker is not cancelled with it.
Every deal ever opened stays subscribed, and each cart change runs one
callback (and one fetch) per old deal.
 
**What I had to learn:** I was not familiar with GetX workers. `ever` returns
a `Worker` object. The subscription lives on the observable it listens to
(here, the permanent `CartService`), not on the controller, so deleting the
controller does not stop it. The `Worker` has to be kept and disposed by hand
in `onClose()`, the same way a `Timer` is cancelled in `dispose()`.
I read the GetX docs on workers and checked the behavior in the console.
 
**Fix:** Keep the `Worker` in a field and call `dispose()` on it in
`onClose()`. Also check `isClosed` after the `await`, so a request that was
already in flight does not update a closed controller.
 
**Rejected alternative:** Return early with `if (isClosed) return;` at the
top of the callback. The requests stop, so the symptom in the ticket goes
away, but the callbacks and the closed controllers stay in memory for the
whole session and still run on every cart change. The leak remains.
 
**Edge cases:**
- Handled: a request still in flight when the user leaves the page.
- Not handled: the open page still re-checks stock when the cart changes for
  a different deal. 
------

### RES-101: Search shows results for the wrong query

**Repro:** Open Search and type "sushi" quickly. The final list often does not
match the text box. TODO: note how many tries and what you saw in the console.

**Root cause:** Each keystroke starts a new request and nothing checks that the
response is still the latest one. The fake API answers short queries more
slowly than long ones, so the reply for "s" can arrive after the reply for
"sushi" and overwrite it. `isLoading` had the same problem: the first request
to finish set it to false while newer requests were still running.

**Fix:** Give each input change an increasing request id. After the `await`,
ignore the result if the id is no longer the newest. Only the newest request
can change `results` or `isLoading`. I also added a 300 ms debounce to send
fewer requests, and cancel the debounce timer in `onClose`.

**Rejected alternative:** Debounce only. It is the classic debounce drawback. It reduces the problem but does not
remove it, because a slow request from earlier can still finish after a fast
one. The request id is what makes the result correct.

**Edge cases:**
- Handled: clearing the text while a request is in flight. The clear bumps
  the id, so a late result cannot fill the list again.
- Handled: an error from an old request is ignored.
- Not handled: cancelling the HTTP request itself. The fake API has no cancel,
  so I only ignore the old result.

------

## Time spent

| Desc | Time Spent |
|---|---|
| Setup (Flutter, Java, repo) | ~30 mins |
| RES-102 | ~10 mins |
| RES-103 | ~25 mins |
| **Total** | **~40 mins** |

## With one more day
- TBD