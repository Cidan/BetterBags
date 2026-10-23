# The Seller (`data/seller.lua`): every sale, one item at a time

Every item BetterBags sells to a merchant goes through one module, `Seller`, at one pace. Callers:
category Auto Sell when a merchant opens (`Automation:StartSale`, automation.md §3), a section sold in
BetterBags Next's vendor dock (a dragged section or a category Auto Sell offers, `NextVendor:SectionOffer`,
automation.md §4a), Classic's Sell Junk (`NextVendor:SellJunk`) and a category title's right click at a
vendor (`SectionFrame:MoveItems`, Move Categories, still ten at most). Selling one at a time is the one
interface for "sell these" (CLAUDE.md "UI Consistency" 5).

## 1. Why

Reported: "autosell (double click or otherwise) will hit 'That object is busy' because i think it's
trying to sell too fast", and items "vanish visually from both vendor and the backpack (though we still
hold the item in our backpack)". Every path used to hand the client all its items in one burst
(`C_Container.UseContainerItem` in a loop): Auto Sell every 0.2 s round, the dock's double click and a
dragged sale once. The client answered most of them `ERR_OBJECT_IS_BUSY` ("That object is busy."), and
a docked sale counted them as sold. The same error is what players describe for other addons that sell
in bulk (r/woweconomy "Any way to Vendor all?": "I get a warning message 'That object is busy'"; Dejunk
is the one reported to sell without it).

Asked: "dejunk's works fine". Dejunk (`src/services/seller.lua`, master, read 2026-10-22) sells one item
per tick of a ticker whose period is `Addon:GetLatency()`: `max(home, world) * 0.001`, at least 0.2 s
(`GetNetStats`), and stops on `ERR_VENDOR_DOESNT_BUY`. The Seller does the same, with the answers below.

**Not measured:** the client's own limit (no capture of a sale yet). A profiler capture shows every beat
(`Seller.Step` returns `"sent"`, `"waiting"`, `"idle"`, `"closed"`, `"refused"`) and how each error was
read (`Seller.OnError` returns `"busy"`, `"refused"`, `"buys nothing"`, `"too far"`, `"other"`,
`"ignored"`).

## 2. The pace

- `Seller:Sell(list, { onDone, onProgress, stillOpen })` queues a sale: ItemData (sold only while the
  slot still holds that item, by GUID) or slots `{ bag, slot }` (Classic's junk, sold as they hold then).
  Sales wait in order on one pace (`jobs`), so two never double the rate.
- `Step` is one beat: the item sent last is answered, then the first sale's next item still there
  (`StillThere`: the item's GUID, never an empty one, unlocked, merchants buy it, not refundable now)
  and not refused by this merchant is sent, and the next beat is scheduled `Interval()` later. With
  nothing left in a sale, it ends and the next one starts in the same beat. With no sale, the pace stops;
  a new sale starts it at once (the last item already had its interval).
- `Interval()`: the larger of `GetNetStats()`'s home and world latency (milliseconds), at least
  `MIN_INTERVAL` (0.2 s).
- It waits a beat at a time while the cursor holds an item (selling with one could sell or swap the
  wrong item; Blizzard's `CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL` question holds the item on the cursor
  until answered, and BetterBags never answers it).
- `onProgress(job)` runs after each item sent (`Left(job)`: how many are still to send); `onDone(job,
  reason)` once: `"done"`, `"closed"` (the merchant closed, the player walked away, or `stillOpen` said
  so), `"refused"` (the merchant buys nothing). `Cancel(job)` ends a sale without calling back.
- A sale's results: `job.sold` (each sent item that was not refused, with how many its slot held,
  `count`) and `job.unsold` (refused, given up after busy tries, never sent).

## 3. The merchant's answers (`UI_ERROR_MESSAGE`)

The item sent last has its interval to be answered; an error the client raises meanwhile is about it.
Messages are compared with the client's global strings (Ketho's BlizzardInterfaceResources enUS,
GlobalStrings): `UI_ERROR_MESSAGE` carries `(errorType, message)` (SystemDocumentation.lua).

| Error | Text | What the Seller does |
|---|---|---|
| `ERR_OBJECT_IS_BUSY` | "That object is busy." | Tries the item again at the end of its sale, after a beat with nothing sent; three tries at most (`MAX_TRIES`), then unsold. |
| `ERR_VENDOR_NOT_INTERESTED`, `ERR_VENDOR_REFUSE_SCRAPPABLE_AZERITE` | "The merchant doesn't want that item." | This merchant refuses it: remembered by the merchant's GUID (`UnitGUID("npc")`) for the session (`Refuses`). |
| `ERR_VENDOR_DOESNT_BUY`, `ERR_VENDOR_HATES_YOU` | "You cannot sell items to this merchant", "That merchant doesn't like you." | Every sale stops (`"refused"`); this merchant is sold nothing again (`BuysNothing`). Says "This merchant buys nothing." |
| `ERR_VENDOR_TOO_FAR` | "You are too far away." | Every sale stops (`"closed"`). |

**Refused items go back to the bags until a merchant buys them** (asked: "refused items go back to the
backpack until we find a merchant that buys it"). They are never destroyed: destroying takes only what
no merchant buys (`hasNoValue`, automation.md §4). Everything that sells leaves them out at this
merchant: `Automation:SellList` (Auto Sell and what the vendor offers), `NextVendor:SaleOf` (a dragged
section) and the Seller itself. Another merchant (another GUID) is offered them again; this merchant is
not, for the session. A sale that ends with refusals says once "This merchant would not buy N items."

`MERCHANT_SHOW` and `MERCHANT_CLOSED` keep `atMerchant`; closing stops every sale (`"closed"`).

## 4. Coverage

`spec/seller_spec.lua`: the interval from the latency and its floor; one item a beat, never two; sales
in order on one pace; waiting for the cursor; skipping items gone, moved, locked, refundable or not
bought; slots without an item; busy retried after a skipped beat, given up after three; a refusal
remembered per merchant (not tried again here, tried at another, still refused back at the first); the
Azerite refusal; a merchant that buys nothing stopping every sale, said once, nothing sold again; one
that dislikes the player; walking away; errors with nothing waiting, and other errors, ignored; the
refusal line; what sold, with each stack's count, once the last item had its interval; progress; the
merchant closing; nothing away from a merchant; `stillOpen` and `Cancel`. `spec/automation_spec.lua`,
`spec/next/vendor_spec.lua`, `spec/frames/section_spec.lua` and `spec/core/init_spec.lua` cover the
callers and that it is initialized and enabled.

Mutation-tested with its callers (Automation, the vendor's offer, the dock's later answers, the drag,
the canvas's leaving redraw, the title's sale): 75 mutations. Eight first survived: five led to tests
(stopping at once when the merchant buys nothing or closes, one answer per item, only "buys nothing"
said after an earlier refusal, a closing guild bank's confirmed deposit) and three were dead code,
removed (Automation's stillOpen checking its sale was not replaced: a replaced sale is cancelled; the
vendor offer clearing a finished sale: cancelling one does nothing; NextDock:Refresh checking the card is
still docked: a card that leaves stops its sale first).

**Not verified in game:** the pace against a real merchant, whether every refusal arrives within one
interval, and that a sold item reads locked or gone by the next beat.
