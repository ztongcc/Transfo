#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "Transfo.h"
#import "TransfoManager.h"
#import "TransfoProcessor.h"
#import "TransfoRequest.h"
#import "TransfoResponse.h"
#import "TransfoUtil.h"

FOUNDATION_EXPORT double TransfoVersionNumber;
FOUNDATION_EXPORT const unsigned char TransfoVersionString[];

