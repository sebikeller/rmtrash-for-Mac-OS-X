#Makefile for rmtrash

CFLAGS=-O3 -g -Wall -Wno-four-char-constants -Wno-unknown-pragmas
LDFLAGS=-framework Foundation -prebind
CC=gcc
DESTDIR=/usr/local

all: rmtrash

install:
	install -s -o root -g wheel -m 755 rmtrash ${DESTDIR}/bin
	install -o root -g wheel -m 644 rmtrash.1 ${DESTDIR}/man/man1

uninstall:
	/bin/rm ${DESTDIR}/bin/rmtrash
	/bin/rm ${DESTDIR}/share/man/man1/rmtrash.1
clean:
	/bin/rm rmtrash 

rmtrash:
	${CC} ${CFLAGS} ${LDFLAGS} rmtrash.m -o rmtrash
