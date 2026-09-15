#ifndef __WINE_MINIMAL_D2D1_H
#define __WINE_MINIMAL_D2D1_H

/* dwrite_private.h includes d2d1.h but the dwrite unix side only uses
 * D2D1_POINT_2F, which is already provided by dcommon.h (widl-generated
 * from dcommon.idl). Avoid generating the whole d2d1.idl closure. */

#include "dcommon.h"

#endif