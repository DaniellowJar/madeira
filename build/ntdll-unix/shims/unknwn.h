#ifndef __WINE_MINIMAL_UNKNWN_H
#define __WINE_MINIMAL_UNKNWN_H

/* widl-generated dwrite.h includes <unknwn.h> for the IUnknown base
 * interface. The real (mingw) unknwn.h assumes a Win32 target and
 * does not compile for arm64-apple-ios. IUnknown and the COM
 * conventions are already provided by our minimal ole2.h shim, so
 * just reuse it. */

#include "ole2.h"

#endif