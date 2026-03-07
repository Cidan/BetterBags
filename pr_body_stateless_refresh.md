### Summary
This pull request completely removes the legacy debounce timer and stateful pending flags (`pendingBackpack`, `pendingBank`, `pendingWipe`) from the `Refresh` module.

### Motivation
The previous architecture introduced an artificial delay (`C_Timer.NewTimer`) and stateful flags that leaked state and fought the natural WoW frame boundaries. By switching to a stateless, immediate execution model (inspired by Moonlight), we rely on the client's built-in `BAG_UPDATE_DELAYED` events to trigger instantaneous redraws. This eliminates micro-stutters and complex edge cases caused by out-of-order debouncing.

### Testing/Validation
- Ran `luacheck` ensuring 0 warnings and 0 errors on modified files.
- Ran the `busted` test suite, resulting in all specs passing successfully.
- Verified that tests specifically account for the removal of the debounce logic and expect synchronous execution.
