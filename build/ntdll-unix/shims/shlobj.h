#ifndef __WINE_MINIMAL_SHLOBJ_H
#define __WINE_MINIMAL_SHLOBJ_H

/* ntuser_private.h includes shlobj.h for the win32u unix side, but no
 * win32u code uses any shell namespace symbols. The real shlobj.h drags
 * in shlguid.h -> exdisp.h/shldisp.h, widl-generated COM web-browser
 * headers that are not built for iOS. Shell data types used elsewhere
 * (SHFILEINFO/SHGetFileInfo) come from shellapi.h, included separately.
 * This no-op shim keeps win32u compilable without the shell COM stack. */

#endif