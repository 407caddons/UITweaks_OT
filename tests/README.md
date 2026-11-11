# Tracker regression tests

Run from the addon root:

```sh
lua tests/run.lua
```

If only the system Lua 5.4 library is installed:

```sh
python3 tests/run.py
```

The suite mocks WoW APIs and exercises combat progress, inaccessible values,
highlight changes, deferred work, quest-model caching, secure button pooling,
viewport clipping, and deferred setup/shutdown. The Python runner uses liblua
only; it does not modify addon files.

Configuration tests also cover addon-owned dropdown selection and scrolling,
popup cleanup, standalone/shared font helpers, and deferred relocking on close.

These tests cannot reproduce WoW's taint tracking, real secret primitives,
secure handlers, or client-specific protected-frame propagation. In-game
testing after a reload is still required, particularly for native tracker
suppression, map interactions, item use, and scrolling around combat changes.

Filter tests cover search-term matching (AND, case-insensitive, inaccessible text), zone modes
and persistence, and building/updating the search box and zone chips on the frame mock.
