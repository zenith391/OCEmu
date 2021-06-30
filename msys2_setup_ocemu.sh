#!/bin/bash
if [ "$MSYSTEM" = "MSYS" ]; then
	echo This script does not work in a 'MSYS2 Shell', use a 'MinGW-w64 Win Shell'
	exit 1
fi
case ${PWD} in *\ * ) echo "Your path has spaces in it which may prevent this script from building correctly."; read -p "Press [Enter] key to continue." ;; esac
case "$MSYSTEM" in
MINGW32) MACHINE_TYPE="i686"
	;;
MINGW64) MACHINE_TYPE="x86_64"
	;;
*) echo "Unknown environment: $MSYSTEM"
	exit 1
	;;
esac
echo "Building OCEmu dependencies for $MACHINE_TYPE"
pacman --needed --noconfirm -S mingw-w64-${MACHINE_TYPE}-toolchain winpty patch make git subversion mingw-w64-${MACHINE_TYPE}-SDL2
mkdir mingw-w64-lua
cd mingw-w64-lua
curl -L https://github.com/Alexpux/MINGW-packages/raw/541d0da31a4d2e648689655e49ddfffbe7ff5dfe/mingw-w64-lua/PKGBUILD -o PKGBUILD
curl -L https://github.com/Alexpux/MINGW-packages/raw/541d0da31a4d2e648689655e49ddfffbe7ff5dfe/mingw-w64-lua/implib.patch -o implib.patch
curl -L https://github.com/Alexpux/MINGW-packages/raw/541d0da31a4d2e648689655e49ddfffbe7ff5dfe/mingw-w64-lua/lua.pc -o lua.pc
curl -L https://github.com/Alexpux/MINGW-packages/raw/541d0da31a4d2e648689655e49ddfffbe7ff5dfe/mingw-w64-lua/searchpath.patch -o searchpath.patch
makepkg-mingw
if [ ! -e mingw-w64-${MACHINE_TYPE}-lua-5.2.4-1-any.pkg.tar.zst ]; then
	echo "Failed to build lua"
	exit 1
fi
pacman --noconfirm -U mingw-w64-${MACHINE_TYPE}-lua-5.2.4-1-any.pkg.tar.zst
cd ..
rm -rf mingw-w64-lua
if [ -e src/extras ]; then
	read -p "src/extras already exists, remove? [y/N] " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]] || [ -z $REPLY ]; then
		echo "Not removing existing folder."
		exit 1
	fi
	rm -rf src/extras
fi
mkdir src/extras
if [ ! -e src/extras ]; then
	echo "Failed to create src/extras folder"
	exit 1
fi
cd src/extras
git clone -b v_1_6_3 --depth=1 https://github.com/keplerproject/luafilesystem.git
if [ ! -e luafilesystem ]; then
	echo "Failed to download luafilesystem"
	exit 1
fi
cd luafilesystem
cat << 'EOF' > lfs_mingw.patch
--- Makefile-old	2015-06-27 10:27:22.594787200 -0600
+++ Makefile	2015-06-27 10:27:32.306801800 -0600
@@ -12 +12 @@
-lib: src/lfs.so
+lib: src/lfs.dll
@@ -14,2 +14,2 @@
-src/lfs.so: $(OBJS)
-	MACOSX_DEPLOYMENT_TARGET="10.3"; export MACOSX_DEPLOYMENT_TARGET; $(CC) $(CFLAGS) $(LIB_OPTION) -o src/lfs.so $(OBJS)
+src/lfs.dll: $(OBJS)
+	MACOSX_DEPLOYMENT_TARGET="10.3"; export MACOSX_DEPLOYMENT_TARGET; $(CC) $(CFLAGS) $(LIB_OPTION) -o src/lfs.dll $(OBJS) -llua
@@ -18 +18 @@
-	LUA_CPATH=./src/?.so lua tests/test.lua
+	LUA_CPATH=./src/?.dll lua tests/test.lua
@@ -22 +22 @@
-	cp src/lfs.so $(LUA_LIBDIR)
+	cp src/lfs.dll $(LUA_LIBDIR)
@@ -25 +25 @@
-	rm -f src/lfs.so $(OBJS)
+	rm -f src/lfs.dll $(OBJS)
EOF
patch < lfs_mingw.patch
make
if [ ! -e src/lfs.dll ]; then
	echo "Failed to build luafilesystem"
	exit 1
fi
mv src/lfs.dll ..
cd ..
rm -rf luafilesystem
git clone -b 0.1.1 --depth=1 https://github.com/starwing/luautf8.git
if [ ! -e luautf8 ]; then
	echo "Failed to download luautf8"
	exit 1
fi
cd luautf8
gcc -O2 -c -o lutf8lib.o lutf8lib.c
gcc -O -shared -o lua-utf8.dll lutf8lib.o -llua
if [ ! -e lua-utf8.dll ]; then
	echo "Failed to build luautf8"
	exit 1
fi
mv lua-utf8.dll ..
cd ..
rm -rf luautf8
git clone --depth=1 https://github.com/gamax92/luaffifb.git
if [ ! -e luaffifb ]; then
	echo "Failed to download luaffifb"
	exit 1
fi
cd luaffifb
cat << 'EOF' > luaffifb_mingw.patch
--- Makefile-old	2015-06-27 10:41:00.288971000 -0600
+++ Makefile.mingw	2015-06-27 10:41:18.062998000 -0600
@@ -6,2 +6,3 @@
-LUA_CFLAGS=`$(PKG_CONFIG) --cflags lua5.2 2>/dev/null || $(PKG_CONFIG) --cflags lua`
-SOCFLAGS=`$(PKG_CONFIG) --libs lua5.2 2>/dev/null || $(PKG_CONFIG) --libs lua`
+LUA_CFLAGS=
+SOCFLAGS=-llua
+CC=gcc
EOF
patch < luaffifb_mingw.patch
make -f Makefile.mingw ffi.dll
if [ ! -e ffi.dll ]; then
	echo "Failed to build luaffifb"
	exit 1
fi
mv ffi.dll ..
cd ..
rm -rf luaffifb
git clone -b v3.0-rc1 --depth=1 https://github.com/diegonehab/luasocket.git

if [ ! -e luasocket ]; then
	echo "Failed to download luasocket"
	exit 1
fi
cd luasocket
cd src
cat << 'EOF' > makefile.patch
--- makefileOLD 2020-11-14 09:17:45.892001600 +0100
+++ makefile    2020-11-14 09:20:57.252003000 +0100
@@ -161,7 +161,7 @@
 SO_mingw=dll
 O_mingw=o
 CC_mingw=gcc
-DEF_mingw= -DLUASOCKET_INET_PTON -DLUASOCKET_$(DEBUG) -DLUA_$(COMPAT)_MODULE \
+DEF_mingw= -DLUASOCKET_$(DEBUG) -DLUA_$(COMPAT)_MODULE \
 	-DWINVER=0x0501 -DLUASOCKET_API='__declspec(dllexport)' \
 	-DMIME_API='__declspec(dllexport)'
 CFLAGS_mingw= -I$(LUAINC) $(DEF) -pedantic -Wall -O2 -fno-common \
EOF
patch < makefile.patch
cd ..
LUALIB_mingw=-llua LUAV=5.2 make mingw
if [ ! -e src/mime.dll.1.0.3 ]; then
	echo "Failed to build luasocket"
	exit 1
fi
prefix=../.. PLAT=mingw CDIR_mingw= LDIR_mingw= make install
cd ..
rm -rf luasocket
git clone -b master https://github.com/brunoos/luasec.git
if [ ! -e luasec ]; then
	echo "Failed to download luasec"
	exit 1
fi
cd luasec
cat << 'EOF' > luasec_mingw.patch
--- src/luasocket/Makefile-old	2015-06-27 11:28:34.279159900 -0600
+++ src/luasocket/Makefile	2015-06-27 11:31:17.381422000 -0600
@@ -5 +5 @@
- usocket.o
+ wsocket.o
@@ -26 +26 @@
-usocket.o: usocket.c socket.h io.h timeout.h usocket.h
+wsocket.o: wsocket.c socket.h io.h timeout.h wsocket.h
--- src/Makefile-old	2015-06-27 11:54:34.670465000 -0600
+++ src/Makefile	2015-06-27 11:54:42.310475600 -0600
@@ -1 +1 @@
-CMOD=ssl.so
+CMOD=ssl.dll
@@ -55 +55 @@
-	$(CCLD) $(LDFLAGS) -o $@ $(OBJS) $(LIBS)
+	$(CCLD) $(LDFLAGS) -o $@ $(OBJS) $(LIBS) -llua -lws2_32
EOF
patch -p0 < luasec_mingw.patch
INC_PATH= LD=gcc CC=gcc make linux
if [ ! -e src/ssl.dll ]; then
	echo "Failed to build luasec"
	exit 1
fi
DESTDIR=../.. LUAPATH= LUACPATH= make install
cd ..
rm -rf luasec
cd ..
echo "Built dependencies!"
gcc -s -o OCEmu.exe winstub.c -Wl,--subsystem,windows -mwindows -llua
case "$MACHINE_TYPE" in
i686)
	cp /mingw32/bin/lua52.dll .
	cp /mingw32/bin/libgcc_s_dw2-1.dll .
	cp /mingw32/bin/libwinpthread-1.dll .
	cp /mingw32/bin/libeay32.dll .
	cp /mingw32/bin/ssleay32.dll .
	cp /mingw32/bin/SDL2.dll .
	;;
x86_64)
	cp /mingw64/bin/lua52.dll .
	cp /mingw64/bin/libgcc_s_seh-1.dll .
	cp /mingw64/bin/libwinpthread-1.dll .
	cp /mingw64/bin/libeay32.dll .
	cp /mingw64/bin/ssleay32.dll .
	;;
esac
strip -s OCEmu.exe *.dll extras/*.dll extras/*/core.dll
date '+%Y%m%d%H%M%S' > builddate.txt
cd ..
echo "Built everything!"
read -p "Download required resources? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [ -z $REPLY ]; then
	make all
fi
