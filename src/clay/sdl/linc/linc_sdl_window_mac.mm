// Title bar of the window on macOS, compiled on macOS only.
//
// Overlay style: the content view takes the whole window (full size content
// view), the title bar is transparent, the title is hidden, and the three
// standard buttons (close, minimize, zoom) can be moved. AppKit puts the
// buttons back at their default place when it lays the title bar out again
// (after a resize, when the window leaves fullscreen, when it becomes key...),
// so observers apply the position again after those notifications.
//
// Position of the buttons: `x` is the distance from the left edge of the
// window to the left edge of the close button, `y` the distance from the top
// edge of the window to the top edge of the buttons, in points. A negative
// value keeps the default place of the system on that axis.

#import <AppKit/AppKit.h>

#ifndef HXCPP_H
#include <hxcpp.h>
#endif

#include "linc_sdl.h"

static int _clayTitleBarStyle = 0;
static CGFloat _clayTitleBarButtonsX = -1;
static CGFloat _clayTitleBarButtonsY = -1;
static BOOL _clayTitleBarButtonsMoved = NO;
// Not retained: the window of the app lives as long as the app
static __unsafe_unretained NSWindow *_clayTitleBarWindow = nil;
static NSMutableArray *_clayTitleBarObservers = nil;

static NSWindow *clayCocoaWindow(SDL_Window *window) {
    if (window == NULL) {
        return nil;
    }
    SDL_PropertiesID props = SDL_GetWindowProperties(window);
    return (__bridge NSWindow *)SDL_GetPointerProperty(props, SDL_PROP_WINDOW_COCOA_WINDOW_POINTER, NULL);
}

// Places the three standard buttons. The view that holds the title bar is
// resized so that the buttons sit at the requested distance from the top.
static void clayLayoutTitleBarButtons(NSWindow *nsWindow) {
    if (nsWindow == nil) {
        return;
    }
    if (([nsWindow styleMask] & NSWindowStyleMaskFullScreen) != 0) {
        // In fullscreen the title bar belongs to another window of the system
        return;
    }
    NSButton *close = [nsWindow standardWindowButton:NSWindowCloseButton];
    NSButton *miniaturize = [nsWindow standardWindowButton:NSWindowMiniaturizeButton];
    NSButton *zoom = [nsWindow standardWindowButton:NSWindowZoomButton];
    if (close == nil || miniaturize == nil || zoom == nil) {
        // Borderless window: no button
        return;
    }
    NSView *titleBarView = [close superview];
    NSView *container = titleBarView != nil ? [titleBarView superview] : nil;
    if (container == nil) {
        return;
    }

    BOOL custom = _clayTitleBarStyle == 1 && (_clayTitleBarButtonsX >= 0 || _clayTitleBarButtonsY >= 0);
    if (!custom) {
        if (_clayTitleBarButtonsMoved) {
            // Back to the layout of the system: AppKit computes it again
            _clayTitleBarButtonsMoved = NO;
            NSRect frame = [nsWindow frame];
            NSRect contentLayout = [nsWindow contentLayoutRect];
            CGFloat height = frame.size.height - (contentLayout.origin.y + contentLayout.size.height);
            NSRect containerFrame = [container frame];
            if (height > 0) {
                containerFrame.size.height = height;
                containerFrame.origin.y = frame.size.height - height;
                [container setFrame:containerFrame];
            }
            [titleBarView setNeedsLayout:YES];
            [titleBarView layoutSubtreeIfNeeded];
        }
        return;
    }

    // Let AppKit finish a pending layout of the title bar first (after a
    // style change for instance), else it would undo the placement below
    NSView *themeFrame = [[nsWindow contentView] superview];
    if (themeFrame != nil) {
        [themeFrame layoutSubtreeIfNeeded];
    }

    NSRect closeFrame = [close frame];
    CGFloat spacing = [miniaturize frame].origin.x - closeFrame.origin.x;
    CGFloat buttonHeight = closeFrame.size.height;
    CGFloat x = _clayTitleBarButtonsX >= 0 ? _clayTitleBarButtonsX : closeFrame.origin.x;

    CGFloat originY = closeFrame.origin.y;
    if (_clayTitleBarButtonsY >= 0) {
        // The container is as high as the buttons plus the same margin above
        // and below them, and stays attached to the top of the window
        CGFloat containerHeight = buttonHeight + 2 * _clayTitleBarButtonsY;
        NSRect containerFrame = [container frame];
        containerFrame.size.height = containerHeight;
        containerFrame.origin.y = [nsWindow frame].size.height - containerHeight;
        [container setFrame:containerFrame];
        originY = _clayTitleBarButtonsY;
    }

    NSButton *buttons[3] = { close, miniaturize, zoom };
    for (int i = 0; i < 3; i++) {
        [buttons[i] setFrameOrigin:NSMakePoint(x + i * spacing, originY)];
    }
    _clayTitleBarButtonsMoved = YES;
}

static void clayObserveTitleBarWindow(NSWindow *nsWindow) {
    if (_clayTitleBarWindow == nsWindow && _clayTitleBarObservers != nil) {
        return;
    }
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (_clayTitleBarObservers != nil) {
        for (id observer in _clayTitleBarObservers) {
            [center removeObserver:observer];
        }
        [_clayTitleBarObservers removeAllObjects];
    }
    else {
        _clayTitleBarObservers = [[NSMutableArray alloc] init];
    }
    _clayTitleBarWindow = nsWindow;
    if (nsWindow == nil) {
        return;
    }
    NSArray *names = @[
        NSWindowDidResizeNotification,
        NSWindowDidEndLiveResizeNotification,
        NSWindowDidExitFullScreenNotification,
        NSWindowDidBecomeKeyNotification,
        NSWindowDidResignKeyNotification,
        NSWindowDidDeminiaturizeNotification,
        NSWindowDidChangeScreenNotification
    ];
    for (NSNotificationName name in names) {
        // queue:nil runs the block on the thread that posts the notification
        // (the main thread for window notifications)
        id observer = [center addObserverForName:name
            object:nsWindow
            queue:nil
            usingBlock:^(NSNotification *notification) {
                NSWindow *target = _clayTitleBarWindow;
                if (target != nil && _clayTitleBarStyle == 1) {
                    clayLayoutTitleBarButtons(target);
                }
            }];
        [_clayTitleBarObservers addObject:observer];
    }
}

namespace linc {
    namespace sdl {

        // style: 0 default (title bar of the system), 1 overlay
        void setWindowTitleBarStyle(SDL_Window* window, int style, float buttonsX, float buttonsY) {
            @autoreleasepool {
                NSWindow *nsWindow = clayCocoaWindow(window);
                if (nsWindow == nil) {
                    return;
                }
                _clayTitleBarStyle = style == 1 ? 1 : 0;
                _clayTitleBarButtonsX = buttonsX;
                _clayTitleBarButtonsY = buttonsY;

                NSWindowStyleMask mask = [nsWindow styleMask];
                BOOL titled = (mask & NSWindowStyleMaskTitled) != 0;
                if (_clayTitleBarStyle == 1) {
                    if (titled && (mask & NSWindowStyleMaskFullSizeContentView) == 0) {
                        [nsWindow setStyleMask:mask | NSWindowStyleMaskFullSizeContentView];
                    }
                    [nsWindow setTitlebarAppearsTransparent:YES];
                    [nsWindow setTitleVisibility:NSWindowTitleHidden];
                    clayObserveTitleBarWindow(nsWindow);
                }
                else {
                    if ((mask & NSWindowStyleMaskFullSizeContentView) != 0) {
                        [nsWindow setStyleMask:mask & ~NSWindowStyleMaskFullSizeContentView];
                    }
                    [nsWindow setTitlebarAppearsTransparent:NO];
                    [nsWindow setTitleVisibility:NSWindowTitleVisible];
                }
                clayLayoutTitleBarButtons(nsWindow);
            }
        }

        // State of the title bar read back from AppKit, for tests:
        // "style=1 fullSize=1 transparent=1 titleHidden=1 close=12,21 spacing=20"
        // (close: left of the close button from the left of the window and
        // top of the button from the top of the window, -1,-1 without buttons)
        ::String windowTitleBarDescribe(SDL_Window* window) {
            @autoreleasepool {
                NSWindow *nsWindow = clayCocoaWindow(window);
                if (nsWindow == nil) {
                    return ::String("");
                }
                NSWindowStyleMask mask = [nsWindow styleMask];
                NSButton *close = [nsWindow standardWindowButton:NSWindowCloseButton];
                NSButton *miniaturize = [nsWindow standardWindowButton:NSWindowMiniaturizeButton];
                CGFloat closeX = -1;
                CGFloat closeY = -1;
                CGFloat spacing = 0;
                if (close != nil) {
                    NSRect inWindow = [close convertRect:[close bounds] toView:nil];
                    closeX = inWindow.origin.x;
                    closeY = [nsWindow frame].size.height - (inWindow.origin.y + inWindow.size.height);
                    if (miniaturize != nil) {
                        spacing = [miniaturize frame].origin.x - [close frame].origin.x;
                    }
                }
                NSString *text = [NSString stringWithFormat:@"style=%d fullSize=%d transparent=%d titleHidden=%d close=%g,%g spacing=%g",
                    _clayTitleBarStyle,
                    (mask & NSWindowStyleMaskFullSizeContentView) != 0 ? 1 : 0,
                    [nsWindow titlebarAppearsTransparent] ? 1 : 0,
                    [nsWindow titleVisibility] == NSWindowTitleHidden ? 1 : 0,
                    (double)closeX, (double)closeY, (double)spacing];
                return ::String::create([text UTF8String]);
            }
        }

    }
}
