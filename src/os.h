/*
** 2001 September 16
**
** The author disclaims copyright to this source code.  In place of
** a legal notice, here is a blessing:
**
**    May you do good and not evil.
**    May you find forgiveness for yourself and forgive others.
**    May you share freely, never taking more than you give.
**
******************************************************************************
**
** This header file (together with is companion C source-code file
** "os.c") attempt to abstract the underlying operating system so that
** the SQLite library will work on both POSIX and windows systems.
*/
#ifndef _SQLITE_OS_H_
#define _SQLITE_OS_H_

#undef sqlite3OsMalloc
#undef sqlite3OsRealloc
#undef sqlite3OsFree

#define sqlite3OsMalloc             sqlite3GenericMalloc
#define sqlite3OsRealloc            sqlite3GenericRealloc
#define sqlite3OsFree               sqlite3GenericFree


#endif /* _SQLITE_OS_H_ */
