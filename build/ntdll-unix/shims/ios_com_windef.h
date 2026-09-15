#ifndef __IOS_COM_WINDEF_H
#define __IOS_COM_WINDEF_H

/* mingw's objidlbase.h / unknwnbase.h use WINBOOL in COM method
 * signatures; iOS has no windef.h to define it. The interfaces are
 * only declared, never called, so an int-compatible type suffices.
 * Guarded so a later windef.h definition still compiles identically.
 */
#ifndef WINBOOL
typedef int WINBOOL;
#endif

#endif