OCEmu - OpenComputers Emulator
==============================

Installation
------------

Needs lua-5.2, luafilesystem, luautf8, luaffi, and SDL2.  
luasocket is optional but is required for the Internet Component and higher precision timing.  
luasec is optional but is required for HTTPS.

This git repository contains submodules, please clone using `git clone --recursive https://github.com/zenith391/OCEmu.git`

### Windows

New Binaries: [Windows 64bit](https://nightly.link/zenith391/OCEmu/workflows/build-win/master/OCEmu.zip)  

**Severely outdated** binaries: [Windows 32bit](https://gamax92.keybase.pub/ocemu/OCEmu-x32.zip) and [Windows 64bit](https://gamax92.keybase.pub/ocemu/OCEmu-x64.zip) (built 2020-04! outdated by a year and half!)

The binaries above have everything pre compiled and packed up for ease of use.

If you'd like to compile OCEmu yourself for Windows, the provided script ```msys2_setup_ocemu.sh``` will automated the compiling process for Windows, run it inside of the [MSYS2](https://msys2.github.io/) environment.  
Ignore the **Lua Libraries** step as it doesn't work on Windows and the script does this for you.

### Ubuntu
```
apt-get install lua5.2 liblua5.2-dev libsdl2-dev subversion
```

Lua 5.2:  
Install a versioned luarocks for 5.2 as described in: http://stackoverflow.com/a/20359102
```
# Download and unpack the latest luarocks from: http://luarocks.org/releases
./configure --lua-version=5.2 --lua-suffix=5.2 --versioned-rocks-dir
make build
sudo make install
```
Lua 5.3:
The same as above but with Lua 5.3:
```
# Download and unpack the latest luarocks from: http://luarocks.org/releases
./configure --lua-version=5.3 --lua-suffix=5.3 --versioned-rocks-dir
make build
sudo make install
```

Follow the [luarocks step](https://github.com/zenith391/OCEmu/tree/master#lua-libraries) below.

### Arch Linux
[Here](https://aur.archlinux.org/packages/ocemu-zenith/) you can directly grab `ocemu-zenith` and its dependencies from the AUR (thanks to [AtomicScience](https://github.com/AtomicScience)).

If you use yay, here is the command:
```
yay -S ocemu-zenith
```

**Manual Build**
Grab the Lua 5.2, luarocks, lua52-filesystem, lua52-sec & lua52-socket from the official repos using Pacman.
```
pacman -S lua52 luarocks lua52-filesystem lua52-sec lua52-socket
```
Then install the luarocks requirements
```
luarocks --lua-version 5.2 install luafilesystem
luarocks --lua-version 5.2 install luautf8
luarocks --lua-version 5.2 install luasocket
luarocks --lua-version 5.2 install luasec
cd luaffifb
luarocks --lua-version 5.2 make

# OpenComputer's lua source code is not provided, if you have svn then use the provided Makefile
# If you hate svn, manually download assets/loot, assets/lua, and assets/font.hex into src/
```

### Mac

Mac users can get up and running quickly by using [brew](http://brew.sh/).

Brew installs luarocks as part of the lua package.
```
# Run this before the luarocks install steps below
brew install lua
brew install sdl2
```
Follow the luarocks steps below.

### Lua Libraries
```
luarocks-5.2 install luafilesystem
luarocks-5.2 install luautf8
luarocks-5.2 install luasocket
luarocks-5.2 install luasec
cd luaffifb
luarocks-5.2 make

# OpenComputer's lua source code is not provided, if you have svn then use the provided Makefile
# If you hate svn, manually download assets/loot, assets/lua, and assets/font.hex into src/
```
For Lua 5.3 support, replace `5.2` by `5.3` in the commands.

Running
-------
Launch boot.lua with lua5.2, and provided everything is installed, you'll have a working Emulator.  
OCEmu stores its files in the following locations:

OS      | Location
------- | ---
Windows | `%APPDATA%\\OCEmu`
Linux   | `$XDG_CONFIG_HOME/ocemu` or `$HOME/.config/ocemu`

```
cd src
lua boot.lua
```

If you want to use a custom path (for example, for running multiple machines with unique filesystems) you can specify the machine path as an argument to boot.lua:

```
cd src
lua boot.lua /path/to/my/emulated/machine_a
```
