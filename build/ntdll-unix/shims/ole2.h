#ifndef __WINE_MINIMAL_OLE2_H
#define __WINE_MINIMAL_OLE2_H

/* Stand-in for wine's include/ole2.h when compiling the dwrite unix
 * side for iOS. The widl-generated dwrite.h #includes "ole2.h" purely
 * for its COM conventions and the IUnknown base class. Pulling in the
 * real ole2.h drags the mingw-w64 COM universe (objidlbase.h,
 * objidl.h, ...) which assumes a Win32 target and does not compile
 * for arm64-apple-ios (missing _WIN32 typedefs and clashing with
 * wine's GetObject/... AW macros).
 *
 * winnt.h (via windef.h, included by unixlib.h before dwrite.h) has
 * already provided HRESULT/LONG/ULONG/etc., so only the COM keywords
 * and IUnknown are defined here. Everything is guarded to coexist
 * with a real ole2.h if one appears earlier on the include path.
 */

#ifndef interface
#define interface struct
#endif

#ifndef STDMETHODCALLTYPE
#define STDMETHODCALLTYPE
#endif

#ifndef __IUnknown_INTERFACE_DEFINED__
#define __IUnknown_INTERFACE_DEFINED__

typedef interface IUnknown IUnknown;
typedef IUnknown *LPUNKNOWN;

typedef struct IUnknownVtbl
{
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(IUnknown *This, const void *riid, void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef)(IUnknown *This);
    ULONG (STDMETHODCALLTYPE *Release)(IUnknown *This);
} IUnknownVtbl;

struct IUnknown
{
    const IUnknownVtbl *lpVtbl;
};
#endif

#endif