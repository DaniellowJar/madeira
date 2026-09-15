#ifndef __WINE_MINIMAL_OLE2_H
#define __WINE_MINIMAL_OLE2_H

/* Stand-in for wine's include/ole2.h when compiling the dwrite unix
 * side for iOS. The widl-generated dwrite.h #includes "ole2.h" purely
 * for its COM base classes (IUnknown, HRESULT, ...). Pulling in the
 * real ole2.h drags the mingw-w64 COM universe (objidlbase.h,
 * objidl.h, ...), which assumes a Win32 target and does not compile
 * for arm64-apple-ios (missing __LONG32, WINBOOL, and wine's
 * GetObject/... AW macros stomp COM method declarations).
 *
 * Guarded typedefs so this coexists with wine's windef.h primitives
 * that unixlib.h already pulled in.
 */

#ifndef HRESULT
typedef long HRESULT;
#endif

#ifndef STDMETHODCALLTYPE
#define STDMETHODCALLTYPE
#endif

#ifndef S_OK
#define S_OK 0L
#endif
#ifndef E_FAIL
#define E_FAIL 0x80004005L
#endif
#ifndef E_NOTIMPL
#define E_NOTIMPL 0x80004001L
#endif

#ifndef __IUnknown_INTERFACE_DEFINED__
#define __IUnknown_INTERFACE_DEFINED__

typedef struct IUnknown IUnknown;
typedef struct IUnknown *LPUNKNOWN;

typedef struct IUnknownVtbl
{
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(IUnknown *This, const void *riid, void **ppvObject);
    unsigned long (STDMETHODCALLTYPE *AddRef)(IUnknown *This);
    unsigned long (STDMETHODCALLTYPE *Release)(IUnknown *This);
} IUnknownVtbl;

struct IUnknown
{
    const IUnknownVtbl *lpVtbl;
};
#endif

#endif