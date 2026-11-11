"""Run the Lua regression suite using system liblua when no Lua CLI is installed."""
import ctypes
import ctypes.util
import sys

library = ctypes.util.find_library("lua5.4")
if not library:
    sys.exit("Install Lua, then run: lua tests/run.lua")
lua = ctypes.CDLL(library)
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]
state = lua.luaL_newstate()
lua.luaL_openlibs(state)
status = lua.luaL_loadfilex(state, b"tests/run.lua", None)
if status == 0:
    status = lua.lua_pcallk(state, 0, -1, 0, 0, None)
if status:
    print(lua.lua_tolstring(state, -1, None).decode(), file=sys.stderr)
lua.lua_close(state)
sys.exit(1 if status else 0)
