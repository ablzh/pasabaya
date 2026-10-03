# 05: Clarify available passenger seats

**What to build:** Drivers set the number of available passenger seats using buttons or direct typing, with a clear explanation that the driver is excluded.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] Label the field Available passenger seats and explicitly explain that the count excludes the driver and represents passenger places offered.
- [x] Minus and plus controls change the value by one; the center remains an editable number input with keyboard support.
- [x] Require a positive whole number through server validation. Do not introduce a 7-seat limit or another arbitrary business cap, and permit direct entry of larger values.
- [x] Reject zero, negative, fractional and malformed values; minus cannot decrement below one, and stepper buttons do not submit the form.
- [x] Seat counts on the ride continue to distinguish seats offered from remaining seats after accepted bookings.
- [x] Keep messaging focused on individual drivers with passenger cars rather than promoting buses or transport businesses.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.




## Implementation evidence

Added Available passenger seats label and driver-exclusion helper text, Stimulus seat stepper controller (+/- without form submission, min 1, editable input, no cap), only_integer validation rejecting 0/-1/1.5/malformed while allowing larger counts, and comprehensive model and system test coverage. Passing full bin/ci with 313 Rails tests and 16 system tests.
