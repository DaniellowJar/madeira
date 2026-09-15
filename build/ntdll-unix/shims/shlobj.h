#ifndef __WINE_MINIMAL_SHLOBJ_H
#define __WINE_MINIMAL_SHLOBJ_H

/* ntuser_private.h includes shlobj.h for the win32u unix side. Only the
 * CF_HDROP drag-drop types are actually used by win32u (clipboard.c).
 * The real shlobj.h drags in the widl-generated shell/COM stack
 * (shobjidl.h -> oleidl.h, shlguid.h -> exdisp.h/shldisp.h) that is not
 * built for iOS. Provide just the drag-drop surface here. DROPEFFECT_*
 * matches the constants widl emits from oleidl.idl; DROPFILES matches
 * wine's shlobj.h. */

#define DROPEFFECT_NONE    0
#define DROPEFFECT_COPY    1
#define DROPEFFECT_MOVE    2
#define DROPEFFECT_LINK    4
#define DROPEFFECT_SCROLL  0x80000000

typedef struct _DROPFILES
{
    DWORD pFiles;
    POINT pt;
    BOOL  fNC;
    BOOL  fWide;
} DROPFILES, *LPDROPFILES;

#endif