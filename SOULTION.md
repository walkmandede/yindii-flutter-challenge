


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
match the text box. 

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
### RES-104: Duplicate deals in the home feed
 
**Repro:** My low-end Android device was too slow to time the gesture (pull
to refresh while page 2 is loading), so I forced the timing from code. I added
a temporary 10 second delay at the start of `loadMore` and a listener on
`deals` that logs the total, unique and duplicate counts. The delay is
artificial, but real network latency creates the same race with a shorter
window. I started `loadMore`, then pulled to refresh during the delay.
 
Before the fix, the console showed:
- After the refresh: `Page: 1, Total: 20, Uniques: 20, Dupes: 0`
- When the delayed `loadMore` finished: `Page: 1, Total: 40, Uniques: 20,
  Dupes: 20`
The delayed `loadMore` also sent `GET /deals?page=1` instead of page 2,
because the refresh had reset `_page` while it was waiting.
 
After the fix: the
stale `loadMore` result is ignored (no new `Page:` line, Total stays 20,
Dupes 0).
 
**Root cause:** `refreshDeals` and `loadMore` share `_page`, `_totalPages`,
`deals` and `_isFetchingMore`, but they do not know about each other. Refresh
resets `_page = 1` and replaces the list. A `loadMore` that was already
running then finishes and appends its result with `addAll` onto the fresh
list. It can also read `_page` after the refresh reset it, which is why the
log shows page 1 being fetched and appended a second time. The catch block
has a similar problem: `_page--` after a refresh can push `_page` to 0.
Because the catalog has a fixed size, this is how the feed ends up with more
items than the catalog contains.
 
**Fix:** A counter, `_refreshId`, that increases on every refresh.
- `refreshDeals` increments it, and after the `await` it drops its result if
  a newer refresh has started.
- `loadMore` remembers the counter when it starts and drops its result if a
  refresh happened in the meantime.
- `_page` is only updated after a successful, current response. `loadMore`
  computes `nextPage` before the request instead of doing `_page++` and
  `_page--`.
- `loadMore` does not run while a refresh is in progress (`_isRefreshing`).
- A stale request cannot reset `_isFetchingMore` or `_isRefreshing` of a
  newer one, because those resets are also checked against the counter.
**Rejected alternative:** Remove duplicates by id when adding items. The list
would look right, but `_page` and `_totalPages` would still be wrong, so
paging would break later. It hides the symptom without fixing the shared
state.
 
Also rejected: ignoring pull to refresh while `loadMore` is running. The user
pulls and nothing happens, which is worse than fixing the race.
 
**Edge cases:**
- Handled: refresh during `loadMore`, `loadMore` during refresh, and a failed
  `loadMore` after a refresh.
- Handled: two refreshes at once. The newest one wins.
- Not handled: cancelling the HTTP request itself. The fake API has no
  cancel, so I only ignore the old result.
- Not handled: error handling for a failed refresh (the refresh indicator is
  not completed on error). That is a separate issue.
---
### RES-106: Wrong pickup times; "Pickup today" filter misses deals

**Repro:** The bakery that opens 06:00 to 09:30 showed "Pick up 23:00 – 02:30".
With "Pickup today" on, some stores with a slot today were missing.

**Root cause:** The backend data is correct. The API sends ISO-8601 UTC
instants, and `DateTime.parse` on a string ending in `Z` returns a UTC
`DateTime`. `DateFormat('HH:mm')` prints those UTC fields, so the label shows
UTC hours. The store is in UTC+7, so 06:00 local is 23:00 UTC. Separately,
`isToday` compared `start.day` (a UTC day of the month) with
`DateTime.now().day` (a local day). A store that opens at 06:00 local starts
on the previous UTC day, so it was filtered out. The check also ignored month
and year.

**Fix:** Convert the parsed instants with `toLocal()` in
`PickupWindowModel.fromJson`, once, where the data enters the app. `isToday`
now compares year, month and day of the local start with the local `now`.
`isOpenNow` and `untilStart` compare instants and did not need changes.

**Rejected alternative:** Hard-code UTC+7 in the app. It would always show the
same hours, but it copies a hidden backend value into the client and breaks
with a second market. Fixing only the label format in the presentation layer also should be rejected, because
`isToday` would still be wrong.

**Edge cases:**
- Handled: stores that open before 07:00 local now appear in "Pickup today".
- Handled: month and year boundaries in `isToday`.
- Handled: overnight windows count as "today" by their start date.
- Not handled: (Currently hardcode time offset) a device in a different time zone from the store (see the
  decision above).
- Not handled: (Rare Case) a time zone change while the app is running. Times parsed
  earlier keep the old zone until the data is reloaded.

---
### RES-105: Home feed is janky and memory keeps climbing
 
**Repro:** Scroll the home feed on a slow physical Android device in profile
mode (`flutter run --profile`,). I added
temporary logs (a `debugPrint` in `HomeScreen.build` and `DealCard.build`, and
a timer that prints the deal count and the image cache size and image count).
I measured with the DevTools Memory tab and the console.
 
**Root causes (three):**
1. **One `Obx` around the whole `Scaffold`.** It read `scrollOffset`, which
   changes on every scroll tick. So the app bar, the flash rail and every
   visible card rebuilt on every tick, even though only two facts were needed:
   offset above 4 (app bar shadow) and above 800 (scroll-to-top button).
2. **The feed was a `ListView` with a `children` list.** Each rebuild (one
   per scroll tick because of cause 1) created a `DealCard` widget for every
   loaded deal and copied the list in `visibleDeals`, so the cost per frame
   grew with each page loaded. (I first thought this built every card at once.
   That was wrong: Flutter only builds the cards near the viewport. The
   cost is the per-rebuild allocation, which the measurements support.)
3. **Full-size image decoding.** The API sends 1600x1200 images shown at about
   160 px high, and `CachedNetworkImage` had no `memCacheWidth`. Each image was
   decoded at full size, so the image cache filled almost at once.
**Before (measured):**
- Console: the same visible `DealCard`s were rebuilt again and again while
  scrolling. `Home Screen has been built` appeared every 34 to 130 ms, each
  pass rebuilding all visible cards and taking about 15 ms, which is most of a
  16 ms frame.
- Image cache: 95.2 MB with 13 images at 20 deals, and exactly the same at 80
  and 120 deals. That is about 7.3 MB per image, a full 1600x1200 decode. The
  cache was full at 13 images, so scrolling likely evicts and re-decodes
  images (not measured directly).
- RAM: RSS about 190 to 260 MB during scrolling, and 365 MB in one earlier
  run. This device varies a lot between runs.

**Fix (three separate commits, measured after each):**
1. `isScrolled` and `showScrollToTop` bools that change only when a threshold is
   crossed. `Obx` now wraps only the app bar, the body data and the
   scroll-to-top button, not the whole screen.
2. `CustomScrollView` with `SliverList.builder`, so only visible cards are
   built and `visibleDeals` is copied only when `deals` or the filter change.
3. `memCacheWidth` in `TheNetworkImage`, from the real layout width
   (read with `LayoutBuilder`) times the device pixel ratio. I set only the
   width so the aspect ratio is kept.
**After (measured):**
- Console: each `DealCard` is built once when it scrolls into view, seconds
  apart, and no repeated `Home Screen has been built` lines appear.
- Image cache: 46.6 MB with 40 images at 40 deals; 52.8 to 57.8 MB with 45 to
  49 images at 60 deals. That is about 1.2 MB per image, about 6 times smaller.
  With the same 100 MB limit, about 6 times more images fit in the cache.
| | Before | After |
|---|---|---|
| Image cache at 40 to 60 deals | 95.2 MB, 13 images | 46.6 to 57.8 MB, 40 to 49 images |
| Size per decoded image | about 7.3 MB | about 1.2 MB |
| Home screen rebuilds while scrolling | every 34 to 130 ms | none seen |
 
Screenshots: TODO add to `docs/res105/` and link here.
 
**What did not change (honest note):** RSS and GC counts looked similar between
runs and are within this device's normal variation, so I do not claim an
improvement there. The image cache limit is the same 100 MB, so at very deep
scroll the total still approaches it. The gain is that images are much smaller,
so it takes far longer to reach the limit and images are less likely to be
evicted and decoded again.
 
**Rejected alternative:** Lowering `imageCache.maximumSizeBytes` on its own. It
caps memory, but each image would still be decoded at full size, so fewer
images would fit and they would be decoded again more often. It treats the
symptom. It could be added on top of right-sized images if a tighter memory
limit is needed.
 
**Edge cases:**
- Handled: the "Pickup today" filter, pull to refresh, load more, the app bar
  shadow and the scroll-to-top button still work.
- Not handled: precaching images ahead of the scroll, and the cost of the
  shimmer placeholder animation while many images load.
- Not handled: very high pixel ratio devices decode larger images. I did not
  cap the ratio.
---

## Time spent

| Desc | Time Spent |
|---|---|
| Setup (Flutter, Java, repo) | ~30 mins |
| RES-102 | ~10 mins |
| RES-103 | ~25 mins |
| RES-101 | ~35 mins |
| RES-104 | ~1hr 30 mins |
| RES-106 | ~20 mins |
| RES-105 | ~2 hr |
| **Total** | **~210 mins** |

## With one more day
- TBD