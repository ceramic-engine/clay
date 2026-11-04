// System settings of macOS that SDL does not expose, compiled on macOS only.
//
// Scrollbar style: `NSScroller.preferredScrollerStyle` is the user's choice
// in System Settings (Appearance, "Show scroll bars"): overlay scrollers
// only show while scrolling, legacy ones are always shown. AppKit posts
// `NSPreferredScrollerStyleDidChangeNotification` on the main thread when it
// changes (the setting, or a mouse being plugged in when the setting is
// automatic); the observer only counts the notifications, and the runtime
// reads the count after pumping the events to emit a change.

#import <AppKit/AppKit.h>

#ifndef HXCPP_H
#include <hxcpp.h>
#endif

#include "linc_sdl.h"

static int _clayScrollerStyleChanges = 0;
static id _clayScrollerStyleObserver = nil;

static void clayObserveScrollerStyle() {
    if (_clayScrollerStyleObserver != nil) {
        return;
    }
    // queue:nil runs the block on the thread that posts the notification
    // (AppKit posts it on the main thread, while SDL pumps the events)
    _clayScrollerStyleObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:NSPreferredScrollerStyleDidChangeNotification
        object:nil
        queue:nil
        usingBlock:^(NSNotification *notification) {
            _clayScrollerStyleChanges++;
        }];
    #if !__has_feature(objc_arc)
    [_clayScrollerStyleObserver retain];
    #endif
}

namespace linc {
    namespace sdl {

        bool autoHideScrollbars() {
            @autoreleasepool {
                clayObserveScrollerStyle();
                return [NSScroller preferredScrollerStyle] == NSScrollerStyleOverlay;
            }
        }

        int autoHideScrollbarsChangeCount() {
            return _clayScrollerStyleChanges;
        }

        void postScrollerStyleChange() {
            @autoreleasepool {
                clayObserveScrollerStyle();
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:NSPreferredScrollerStyleDidChangeNotification
                    object:nil];
            }
        }

    }
}
