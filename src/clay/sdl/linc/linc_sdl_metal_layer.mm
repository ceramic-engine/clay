// Number of drawables of the CAMetalLayer the app renders to, macOS and iOS.
//
// With ANGLE's Metal backend the GL surface of the window is a CAMetalLayer:
// the layer of the view when it already is one, else a sublayer ANGLE adds
// to it when the EGL surface is created. ANGLE never sets
// `maximumDrawableCount`, so the layer keeps the system default of 3: with
// vsync, a presented frame then waits behind two older ones. With 2 it waits
// behind one.
//
// The layer is found by walking the layer tree of the window, so this works
// whoever created it (SDL, ANGLE) and can be called again at any time: the
// layer can be replaced when the surface is created again.
//
// Objective-C rather than the C runtime API (objc_msgSend): the file is
// compiled for Apple targets only, the calls are type checked, and clay
// already has .mm files next to this one.

#import <TargetConditionals.h>
#import <QuartzCore/CAMetalLayer.h>

#include <SDL3/SDL.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

#ifndef HXCPP_H
#include <hxcpp.h>
#endif

#include "linc_sdl.h"

static int claySetMaxDrawables(CALayer *layer, NSUInteger count, int depth) {
    if (layer == nil || depth > 16) {
        return 0;
    }
    // The class is looked up by name so that this file does not need the app
    // to link QuartzCore itself (ANGLE does)
    static Class metalLayerClass = NSClassFromString(@"CAMetalLayer");
    int found = 0;
    if (metalLayerClass != Nil && [layer isKindOfClass:metalLayerClass]) {
        CAMetalLayer *metalLayer = (CAMetalLayer *)layer;
        if (metalLayer.maximumDrawableCount != count) {
            metalLayer.maximumDrawableCount = count;
        }
        found++;
    }
    for (CALayer *sublayer in layer.sublayers) {
        found += claySetMaxDrawables(sublayer, count, depth + 1);
    }
    return found;
}

namespace linc {
    namespace sdl {

        // Sets `maximumDrawableCount` (2 or 3, the only values Metal accepts)
        // on every CAMetalLayer of the window. Returns how many were found.
        int setWindowMaxDrawables(SDL_Window* window, int count) {
            if (window == NULL) {
                return 0;
            }
            NSUInteger value = count <= 2 ? 2 : 3;
            @autoreleasepool {
                SDL_PropertiesID props = SDL_GetWindowProperties(window);
                #if TARGET_OS_OSX
                NSWindow *nsWindow = (__bridge NSWindow *)SDL_GetPointerProperty(props, SDL_PROP_WINDOW_COCOA_WINDOW_POINTER, NULL);
                if (nsWindow == nil) {
                    return 0;
                }
                return claySetMaxDrawables(nsWindow.contentView.layer, value, 0);
                #else
                UIWindow *uiWindow = (__bridge UIWindow *)SDL_GetPointerProperty(props, SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, NULL);
                if (uiWindow == nil) {
                    return 0;
                }
                return claySetMaxDrawables(uiWindow.layer, value, 0);
                #endif
            }
        }

    }
}
