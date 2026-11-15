// Phase of the scroll events on macOS (trackpad and Magic Mouse gestures,
// their momentum), compiled on macOS only.
//
// SDL turns each scroll `NSEvent` into one `SDL_EVENT_MOUSE_WHEEL` but drops
// its `phase` and `momentumPhase`. A local event monitor sees every scroll
// event the app dispatches just before AppKit hands it to the window, so it
// records the phase of each one in a queue, and the runtime takes the
// recorded phase back when it handles the matching SDL event.
//
// Keeping both in step:
// - SDL's view handles the event in `Cocoa_HandleMouseWheel`
//   (SDL_cocoamouse.m), which sends one wheel event with the deltas computed
//   below, unless both deltas are zero (`SDL_SendMouseWheel` drops those).
//   The monitor computes the same deltas, the same way, so it knows which
//   events SDL sends, and each SDL event is matched with the oldest recorded
//   event that has the same deltas. A recorded event that SDL did not send
//   (an event SDL handles another way, see `USE_GCMOUSE_SCROLL`, off in this
//   SDL) is skipped by the next match, or dropped after two flushes.
// - Events with zero deltas carry phases an app needs (the fingers touch the
//   trackpad, a gesture or its momentum ends): SDL drops them, so the
//   runtime forwards them itself (`takeLoneScrollPhase`), in their order
//   relative to the wheel events.
// - Only events of SDL windows are recorded (an event of another window,
//   such as a system panel, never reaches SDL).
//
// Phase values (clay and `ceramic.ScrollPhase`): 0 none (a mouse wheel),
// 1 gesture began, 2 gesture, 3 gesture ended, 4 gesture cancelled,
// 5 momentum began, 6 momentum, 7 momentum ended, 8 gesture may begin.

#import <AppKit/AppKit.h>
#include <unistd.h>

#ifndef HXCPP_H
#include <hxcpp.h>
#endif

#include "linc_sdl.h"

namespace {

    struct ClayScrollEntry {
        float x;
        float y;
        int phase;
        SDL_WindowID windowID;
        int flushes;
    };

    // Ring buffers, the oldest entry first. The queue only holds the events
    // of one pump of SDL in practice: when full, the oldest entry is dropped.
    const int CLAY_SCROLL_CAPACITY = 256;

    ClayScrollEntry _clayScrollQueue[CLAY_SCROLL_CAPACITY];
    int _clayScrollQueueStart = 0;
    int _clayScrollQueueCount = 0;

    // Zero delta events to forward: `phase | (windowID << 8)`
    int _clayScrollLone[CLAY_SCROLL_CAPACITY];
    int _clayScrollLoneStart = 0;
    int _clayScrollLoneCount = 0;

    id _clayScrollMonitor = nil;

    // Test support: the window that receives the events posted by
    // `scrollPhaseTestPost` (hidden windows get no event from the system)
    __unsafe_unretained NSWindow *_clayScrollTestWindow = nil;
    SDL_WindowID _clayScrollTestWindowID = 0;
    int _clayScrollTestDelivered = 0;

}

static void clayScrollPushLone(int phase, SDL_WindowID windowID) {
    if (_clayScrollLoneCount == CLAY_SCROLL_CAPACITY) {
        _clayScrollLoneStart = (_clayScrollLoneStart + 1) % CLAY_SCROLL_CAPACITY;
        _clayScrollLoneCount--;
    }
    _clayScrollLone[(_clayScrollLoneStart + _clayScrollLoneCount) % CLAY_SCROLL_CAPACITY] = phase | ((int)windowID << 8);
    _clayScrollLoneCount++;
}

static void clayScrollPush(float x, float y, int phase, SDL_WindowID windowID) {
    if (_clayScrollQueueCount == CLAY_SCROLL_CAPACITY) {
        _clayScrollQueueStart = (_clayScrollQueueStart + 1) % CLAY_SCROLL_CAPACITY;
        _clayScrollQueueCount--;
    }
    ClayScrollEntry &entry = _clayScrollQueue[(_clayScrollQueueStart + _clayScrollQueueCount) % CLAY_SCROLL_CAPACITY];
    entry.x = x;
    entry.y = y;
    entry.phase = phase;
    entry.windowID = windowID;
    entry.flushes = 0;
    _clayScrollQueueCount++;
}

static void clayScrollPop() {
    _clayScrollQueueStart = (_clayScrollQueueStart + 1) % CLAY_SCROLL_CAPACITY;
    _clayScrollQueueCount--;
}

static inline ClayScrollEntry &clayScrollAt(int index) {
    return _clayScrollQueue[(_clayScrollQueueStart + index) % CLAY_SCROLL_CAPACITY];
}

static inline bool clayScrollIsLone(const ClayScrollEntry &entry) {
    return entry.x == 0.0f && entry.y == 0.0f;
}

static int clayScrollPhaseOf(NSEvent *event) {
    NSEventPhase momentum = [event momentumPhase];
    if (momentum != NSEventPhaseNone) {
        if (momentum & (NSEventPhaseEnded | NSEventPhaseCancelled)) return 7;
        if (momentum & (NSEventPhaseBegan | NSEventPhaseMayBegin)) return 5;
        return 6;
    }
    NSEventPhase phase = [event phase];
    if (phase == NSEventPhaseNone) return 0;
    if (phase & NSEventPhaseMayBegin) return 8;
    if (phase & NSEventPhaseBegan) return 1;
    if (phase & NSEventPhaseEnded) return 3;
    if (phase & NSEventPhaseCancelled) return 4;
    return 2;
}

static NSWindow *clayScrollCocoaWindow(SDL_Window *window) {
    SDL_PropertiesID props = SDL_GetWindowProperties(window);
    return (__bridge NSWindow *)SDL_GetPointerProperty(props, SDL_PROP_WINDOW_COCOA_WINDOW_POINTER, NULL);
}

// The SDL window of an AppKit window, 0 if it is not an SDL window
static SDL_WindowID clayScrollWindowID(NSWindow *nsWindow) {
    if (nsWindow == nil) {
        return 0;
    }
    int count = 0;
    SDL_Window **windows = SDL_GetWindows(&count);
    SDL_WindowID result = 0;
    if (windows != NULL) {
        for (int i = 0; i < count; i++) {
            if (clayScrollCocoaWindow(windows[i]) == nsWindow) {
                result = SDL_GetWindowID(windows[i]);
                break;
            }
        }
        SDL_free(windows);
    }
    return result;
}

static void clayScrollRecord(NSEvent *event, SDL_WindowID windowID) {
    // The deltas of Cocoa_HandleMouseWheel (SDL_cocoamouse.m), computed the
    // same way so that the floats compare equal
    CGFloat x, y;
    if ([event hasPreciseScrollingDeltas]) {
        x = -[event scrollingDeltaX] * 0.1f;
        y = [event scrollingDeltaY] * 0.1f;
    } else {
        x = -[event deltaX];
        y = [event deltaY];
        if (x > 0) {
            x = SDL_ceil(x);
        } else if (x < 0) {
            x = SDL_floor(x);
        }
        if (y > 0) {
            y = SDL_ceil(y);
        } else if (y < 0) {
            y = SDL_floor(y);
        }
    }
    int phase = clayScrollPhaseOf(event);
    float fx = (float)x;
    float fy = (float)y;
    if (fx == 0.0f && fy == 0.0f && phase == 0) {
        // Nothing to forward: no movement and no phase
        return;
    }
    clayScrollPush(fx, fy, phase, windowID);
}

namespace linc {

    namespace sdl {

        bool installScrollPhaseMonitor() {
            if (_clayScrollMonitor != nil) {
                return true;
            }
            @autoreleasepool {
                _clayScrollMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskScrollWheel handler:^NSEvent *(NSEvent *event) {
                    NSWindow *nsWindow = [event window];
                    if (nsWindow == nil && _clayScrollTestWindow != nil) {
                        // Test support: an event posted by scrollPhaseTestPost,
                        // handed to the hidden window as AppKit would
                        clayScrollRecord(event, _clayScrollTestWindowID);
                        _clayScrollTestDelivered++;
                        [[_clayScrollTestWindow contentView] scrollWheel:event];
                        return nil;
                    }
                    SDL_WindowID windowID = clayScrollWindowID(nsWindow);
                    if (windowID != 0) {
                        clayScrollRecord(event, windowID);
                    }
                    return event;
                }];
                #if !__has_feature(objc_arc)
                [_clayScrollMonitor retain];
                #endif
            }
            return _clayScrollMonitor != nil;
        }

        int takeScrollPhase(float x, float y) {
            // The oldest recorded event with these deltas
            int match = -1;
            for (int i = 0; i < _clayScrollQueueCount; i++) {
                ClayScrollEntry &entry = clayScrollAt(i);
                if (!clayScrollIsLone(entry) && entry.x == x && entry.y == y) {
                    match = i;
                    break;
                }
            }
            if (match < 0) {
                return 0;
            }
            // Zero delta events before it are forwarded first, events SDL did
            // not send are dropped
            for (int i = 0; i < match; i++) {
                ClayScrollEntry &entry = clayScrollAt(0);
                if (clayScrollIsLone(entry)) {
                    clayScrollPushLone(entry.phase, entry.windowID);
                }
                clayScrollPop();
            }
            int phase = clayScrollAt(0).phase;
            clayScrollPop();
            return phase;
        }

        int takeLoneScrollPhase() {
            if (_clayScrollLoneCount == 0) {
                return -1;
            }
            int value = _clayScrollLone[_clayScrollLoneStart];
            _clayScrollLoneStart = (_clayScrollLoneStart + 1) % CLAY_SCROLL_CAPACITY;
            _clayScrollLoneCount--;
            return value;
        }

        void flushScrollPhases() {
            // After the SDL events of a pump: zero delta events at the front
            // follow the last wheel event handled. An event with deltas still
            // there may belong to a wheel event SDL has queued and not
            // delivered yet: it waits, unless it stayed through two flushes
            // (SDL did not send it).
            while (_clayScrollQueueCount > 0) {
                ClayScrollEntry &entry = clayScrollAt(0);
                if (clayScrollIsLone(entry)) {
                    clayScrollPushLone(entry.phase, entry.windowID);
                    clayScrollPop();
                }
                else if (entry.flushes >= 2) {
                    clayScrollPop();
                }
                else {
                    break;
                }
            }
            for (int i = 0; i < _clayScrollQueueCount; i++) {
                clayScrollAt(i).flushes++;
            }
        }

        bool scrollPhaseTestPost(SDL_Window* window, int phase, int momentumPhase, int deltaX, int deltaY, bool pixels) {
            if (window == NULL || _clayScrollMonitor == nil) {
                return false;
            }
            @autoreleasepool {
                _clayScrollTestWindow = clayScrollCocoaWindow(window);
                _clayScrollTestWindowID = SDL_GetWindowID(window);
                if (_clayScrollTestWindow == nil) {
                    return false;
                }
                CGEventRef event = CGEventCreateScrollWheelEvent2(NULL, pixels ? kCGScrollEventUnitPixel : kCGScrollEventUnitLine, 2, deltaY, deltaX, 0);
                if (event == NULL) {
                    return false;
                }
                CGEventSetIntegerValueField(event, kCGScrollWheelEventIsContinuous, pixels ? 1 : 0);
                CGEventSetIntegerValueField(event, kCGScrollWheelEventScrollPhase, phase);
                CGEventSetIntegerValueField(event, kCGScrollWheelEventMomentumPhase, momentumPhase);
                // To this process only, never to the system
                CGEventPostToPid(getpid(), event);
                CFRelease(event);
            }
            return true;
        }

        int scrollPhaseTestDelivered() {
            return _clayScrollTestDelivered;
        }

    }

}
