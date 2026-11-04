// Native application menu bar for macOS (NSMenu), compiled on macOS only.
//
// The menu bar is built from Haxe (menuBarBegin, menuBarAddItem,
// menuBarCommit) and installed as the main menu of SDL's NSApplication,
// replacing the default menus SDL creates at startup.
//
// Items use the selector `clayMenuItem:` (or `cut:`, `copy:`, `paste:`,
// `selectAll:` for the standard edit items) with no target, so that the
// action travels the responder chain: a system panel with a text field
// (a file dialog) gets the edit actions, and otherwise the application
// delegate gets them. The methods are added to the delegate's class at
// runtime; when that is not possible, items target a private handler
// object instead.
//
// The dock menu (dockMenuBegin, dockMenuAddItem, dockMenuCommit) is built
// the same way and given to AppKit by `applicationDockMenu:`, added to the
// class of the application delegate like GPUI's delegate implements it. Its
// items use the same selectors, validation and callbacks as the menu bar.
//
// Key equivalents: SDL hands every key down to the app (as an SDL event)
// before AppKit dispatches it, and AppKit then offers it to the key window
// and to the main menu (`performKeyEquivalent:`). A native window gets the
// key first and the menu only runs the item when the window did not handle
// it. To keep that order, the main menu matches the item as usual but does
// not run it: the id of the item is kept with the timestamp of the SDL key
// down (recorded by an SDL event watch while the same NSEvent is being
// dispatched), and the runtime reports it after delivering that key down
// to the app (`takeMenuKeyEquivalent`), which decides whether the item runs.
// Key downs that SDL did not deliver to the app (no keyboard focus, a
// system panel being the key window) go through the menu unchanged.

#import <AppKit/AppKit.h>
#import <objc/runtime.h>

#ifndef HXCPP_H
#include <hxcpp.h>
#endif

#include "linc_sdl.h"

#if __has_feature(objc_arc)
#define CLAY_MENU_RELEASE(x)
#else
#define CLAY_MENU_RELEASE(x) [(x) release]
#endif

namespace linc {
    namespace sdl {
        static InternalMenuValidateCallback _menuValidate = NULL;
        static InternalMenuActionCallback _menuAction = NULL;
        static InternalMenuWillOpenCallback _menuWillOpen = NULL;
        static bool _menuCallbacksSet = false;
    }
}

// Menus being built: index 0 is the root, other indices are submenu handles
static NSMutableArray *_clayMenus = nil;

// The dock menu being built (index 0 is its root) and the one installed
static NSMutableArray *_clayDockMenus = nil;
static NSMenu *_clayDockMenu = nil;

// Handler object: delegate of every menu, target of the items when the
// application delegate could not be given the item methods
static id _clayMenuHandler = nil;

// Class of the application delegate the item methods were added to
static Class _clayMenuGraftedClass = Nil;

// Whether items have no target (responder chain to the application delegate)
static BOOL _clayMenuUseResponderChain = NO;

// While the main menu matches a key equivalent for the app: items record
// their id instead of running
static BOOL _clayMenuDeferring = NO;
static int _clayMenuDeferredId = -1;

// The NSEvent of the last key down SDL delivered to the app, and the
// timestamp of the SDL event
static BOOL _clayMenuKeyValid = NO;
static void *_clayMenuKeyEvent = NULL;
static NSTimeInterval _clayMenuKeyEventTime = 0;
static Uint64 _clayMenuKeyTimestamp = 0;

// Items matched for key downs, waiting for the app to receive the key down
struct ClayMenuPendingKey {
    Uint64 timestamp;
    int id;
};
static const int CLAY_MENU_MAX_PENDING = 32;
static ClayMenuPendingKey _clayMenuPending[CLAY_MENU_MAX_PENDING];
static int _clayMenuPendingCount = 0;

static bool _clayMenuWatchInstalled = false;

static void clayMenuPushPending(Uint64 timestamp, int id) {
    if (_clayMenuPendingCount >= CLAY_MENU_MAX_PENDING) {
        // Should not happen (cleared after each batch of events): drop the oldest
        for (int i = 1; i < CLAY_MENU_MAX_PENDING; i++) {
            _clayMenuPending[i - 1] = _clayMenuPending[i];
        }
        _clayMenuPendingCount--;
    }
    _clayMenuPending[_clayMenuPendingCount].timestamp = timestamp;
    _clayMenuPending[_clayMenuPendingCount].id = id;
    _clayMenuPendingCount++;
}

static int clayMenuTakePending(Uint64 timestamp) {
    for (int i = 0; i < _clayMenuPendingCount; i++) {
        if (_clayMenuPending[i].timestamp == timestamp) {
            int id = _clayMenuPending[i].id;
            for (int j = i + 1; j < _clayMenuPendingCount; j++) {
                _clayMenuPending[j - 1] = _clayMenuPending[j];
            }
            _clayMenuPendingCount--;
            return id;
        }
    }
    return -1;
}

static void clayMenuHandleItem(id sender) {
    if (![sender isKindOfClass:[NSMenuItem class]]) {
        return;
    }
    int tag = (int)[(NSMenuItem *)sender tag];
    if (_clayMenuDeferring) {
        _clayMenuDeferredId = tag;
        return;
    }
    if (linc::sdl::_menuCallbacksSet) {
        linc::sdl::_menuAction(tag);
    }
}

static BOOL clayMenuValidateItem(NSMenuItem *item) {
    if (_clayMenuDeferring) {
        // The app decides once it has seen the key down
        return YES;
    }
    if (!linc::sdl::_menuCallbacksSet) {
        return NO;
    }
    return linc::sdl::_menuValidate((int)[item tag]) != 0 ? YES : NO;
}

@interface ClayMenuHandler : NSObject <NSMenuDelegate>
@end

@implementation ClayMenuHandler

- (void)clayMenuItem:(id)sender {
    clayMenuHandleItem(sender);
}

- (void)cut:(id)sender {
    clayMenuHandleItem(sender);
}

- (void)copy:(id)sender {
    clayMenuHandleItem(sender);
}

- (void)paste:(id)sender {
    clayMenuHandleItem(sender);
}

- (void)selectAll:(id)sender {
    clayMenuHandleItem(sender);
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    return clayMenuValidateItem(item);
}

- (void)menuWillOpen:(NSMenu *)menu {
    if (linc::sdl::_menuCallbacksSet) {
        linc::sdl::_menuWillOpen();
    }
}

@end

static BOOL clayMenuIsKeyForApp(NSEvent *event) {
    return _clayMenuKeyValid
        && (void *)event == _clayMenuKeyEvent
        && [event timestamp] == _clayMenuKeyEventTime;
}

@interface ClayMenuBar : NSMenu
@end

@implementation ClayMenuBar

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    if (!clayMenuIsKeyForApp(event)) {
        return [super performKeyEquivalent:event];
    }
    Uint64 timestamp = _clayMenuKeyTimestamp;
    _clayMenuDeferring = YES;
    _clayMenuDeferredId = -1;
    BOOL handled = NO;
    @try {
        handled = [super performKeyEquivalent:event];
    }
    @finally {
        _clayMenuDeferring = NO;
    }
    int id = _clayMenuDeferredId;
    _clayMenuDeferredId = -1;
    if (id >= 0) {
        clayMenuPushPending(timestamp, id);
        return YES;
    }
    return handled;
}

@end

static SEL clayMenuItemSelectors[] = {
    @selector(clayMenuItem:),
    @selector(cut:),
    @selector(copy:),
    @selector(paste:),
    @selector(selectAll:),
    @selector(validateMenuItem:)
};

static const int CLAY_MENU_SELECTOR_COUNT = 6;

// Adds the item methods to the class of the application delegate, like
// GPUI's application delegate implements them. Returns NO when the class
// already has one of them (another delegate than SDL's).
static BOOL clayMenuGraftOnto(Class cls) {
    if (cls == Nil) {
        return NO;
    }
    if (cls == _clayMenuGraftedClass) {
        return YES;
    }
    for (int i = 0; i < CLAY_MENU_SELECTOR_COUNT; i++) {
        if (class_respondsToSelector(cls, clayMenuItemSelectors[i])) {
            return NO;
        }
    }
    Class handlerClass = [ClayMenuHandler class];
    for (int i = 0; i < CLAY_MENU_SELECTOR_COUNT; i++) {
        Method method = class_getInstanceMethod(handlerClass, clayMenuItemSelectors[i]);
        class_addMethod(cls, clayMenuItemSelectors[i], method_getImplementation(method), method_getTypeEncoding(method));
    }
    _clayMenuGraftedClass = cls;
    return YES;
}

static NSMenu *clayMenuDockMenu(id self, SEL _cmd, NSApplication *sender) {
    return _clayDockMenu;
}

// Adds `applicationDockMenu:` to the class of the application delegate.
// Returns NO when the class already has its own (another delegate than SDL's).
static Class _clayDockMenuGraftedClass = Nil;

static BOOL clayMenuGraftDockMenu(Class cls) {
    if (cls == Nil) {
        return NO;
    }
    if (cls == _clayDockMenuGraftedClass) {
        return YES;
    }
    SEL selector = @selector(applicationDockMenu:);
    if (class_respondsToSelector(cls, selector)) {
        return NO;
    }
    class_addMethod(cls, selector, (IMP)clayMenuDockMenu, "@@:@");
    _clayDockMenuGraftedClass = cls;
    return YES;
}

static bool clayMenuKeyWatch(void *userdata, SDL_Event *event) {
    if (event->type == SDL_EVENT_KEY_DOWN && [NSThread isMainThread]) {
        NSEvent *current = [NSApp currentEvent];
        if (current != nil && [current type] == NSEventTypeKeyDown) {
            _clayMenuKeyValid = YES;
            _clayMenuKeyEvent = (void *)current;
            _clayMenuKeyEventTime = [current timestamp];
            _clayMenuKeyTimestamp = event->key.timestamp;
        }
    }
    return true;
}

static NSString *clayMenuString(::String value) {
    if (value.__s == NULL) {
        return @"";
    }
    const char *utf8 = value.utf8_str();
    NSString *result = utf8 != NULL ? [NSString stringWithUTF8String:utf8] : nil;
    return result != nil ? result : @"";
}

// GPUI's key_to_native (gpui-pre-macos 0.3.10 src/events.rs): key names to
// the characters AppKit uses for key equivalents, anything else as is
static NSString *clayMenuKeyToNative(NSString *key) {
    static NSDictionary *names = nil;
    if (names == nil) {
        NSMutableDictionary *map = [[NSMutableDictionary alloc] init];
        map[@"space"] = @(0x20);
        map[@"backspace"] = @(0x7f);
        map[@"escape"] = @(0x1b);
        map[@"up"] = @(NSUpArrowFunctionKey);
        map[@"down"] = @(NSDownArrowFunctionKey);
        map[@"left"] = @(NSLeftArrowFunctionKey);
        map[@"right"] = @(NSRightArrowFunctionKey);
        map[@"pageup"] = @(NSPageUpFunctionKey);
        map[@"pagedown"] = @(NSPageDownFunctionKey);
        map[@"home"] = @(NSHomeFunctionKey);
        map[@"end"] = @(NSEndFunctionKey);
        map[@"delete"] = @(NSDeleteFunctionKey);
        map[@"insert"] = @(NSHelpFunctionKey);
        for (int i = 1; i <= 35; i++) {
            map[[NSString stringWithFormat:@"f%d", i]] = @(NSF1FunctionKey + i - 1);
        }
        names = map;
    }
    NSNumber *code = names[key];
    if (code == nil) {
        return key;
    }
    unichar c = (unichar)[code unsignedShortValue];
    return [NSString stringWithCharacters:&c length:1];
}

static NSEventModifierFlags clayMenuModifierMask(int modifiers) {
    NSEventModifierFlags mask = 0;
    if (modifiers & 8) mask |= NSEventModifierFlagCommand;
    if (modifiers & 2) mask |= NSEventModifierFlagControl;
    if (modifiers & 4) mask |= NSEventModifierFlagOption;
    if (modifiers & 1) mask |= NSEventModifierFlagShift;
    return mask;
}

static NSMenuItem *clayMenuFindItem(NSMenu *menu, int id, NSMenu **owner) {
    for (NSMenuItem *item in [menu itemArray]) {
        if (![item isSeparatorItem] && [item tag] == id) {
            if (owner != NULL) *owner = menu;
            return item;
        }
        if ([item submenu] != nil) {
            NSMenuItem *found = clayMenuFindItem([item submenu], id, owner);
            if (found != nil) return found;
        }
    }
    return nil;
}

static void clayMenuDescribe(NSMenu *menu, int depth, NSMutableString *out) {
    for (NSMenuItem *item in [menu itemArray]) {
        for (int i = 0; i < depth; i++) [out appendString:@"  "];
        if ([item isSeparatorItem]) {
            [out appendString:@"---\n"];
            continue;
        }
        NSMutableString *key = [NSMutableString string];
        NSString *equivalent = [item keyEquivalent];
        for (NSUInteger i = 0; i < [equivalent length]; i++) {
            unichar c = [equivalent characterAtIndex:i];
            if (c >= 0x21 && c < 0x7f) {
                [key appendFormat:@"%C", c];
            } else {
                [key appendFormat:@"U+%04X", c];
            }
        }
        NSEventModifierFlags mask = [item keyEquivalentModifierMask];
        NSMutableString *mods = [NSMutableString string];
        if (mask & NSEventModifierFlagCommand) [mods appendString:@"cmd-"];
        if (mask & NSEventModifierFlagControl) [mods appendString:@"ctrl-"];
        if (mask & NSEventModifierFlagOption) [mods appendString:@"alt-"];
        if (mask & NSEventModifierFlagShift) [mods appendString:@"shift-"];
        SEL action = [item action];
        [out appendFormat:@"%@ key=%@ mods=%@ action=%@ tag=%ld state=%ld enabled=%d target=%@",
            [item title], key, mods, action != NULL ? NSStringFromSelector(action) : @"-",
            (long)[item tag], (long)[item state], [item isEnabled] ? 1 : 0,
            [item target] != nil ? @"handler" : @"chain"];
        if ([item submenu] != nil) {
            NSMenu *submenu = [item submenu];
            if (submenu == [NSApp windowsMenu]) [out appendString:@" windowsMenu"];
            if (submenu == [NSApp servicesMenu]) [out appendString:@" servicesMenu"];
            [out appendFormat:@" delegate=%d\n", [submenu delegate] == _clayMenuHandler ? 1 : 0];
            clayMenuDescribe(submenu, depth + 1, out);
        } else {
            [out appendString:@"\n"];
        }
    }
}

namespace linc {
    namespace sdl {

        void setMenuCallbacks(InternalMenuValidateCallback validate, InternalMenuActionCallback action, InternalMenuWillOpenCallback willOpen) {
            _menuValidate = validate;
            _menuAction = action;
            _menuWillOpen = willOpen;
            _menuCallbacksSet = true;
        }

        void menuBarBegin() {
            @autoreleasepool {
                if (_clayMenuHandler == nil) {
                    _clayMenuHandler = [[ClayMenuHandler alloc] init];
                }
                _clayMenuUseResponderChain = clayMenuGraftOnto([[NSApp delegate] class]);
                if (_clayMenus != nil) {
                    CLAY_MENU_RELEASE(_clayMenus);
                }
                _clayMenus = [[NSMutableArray alloc] init];
                ClayMenuBar *root = [[ClayMenuBar alloc] initWithTitle:@""];
                [root setDelegate:_clayMenuHandler];
                [_clayMenus addObject:root];
                CLAY_MENU_RELEASE(root);
            }
        }

        // Adds an item to `menus` (the menu bar, or the dock menu when
        // `isDock`: no Services or Window menu there)
        static int clayMenuAddItem(NSMutableArray *menus, bool isDock, int parent, int kind, ::String title, ::String key, int modifiers, int role, int id, bool enabled, bool checked) {
            @autoreleasepool {
                if (menus == nil || parent < 0 || parent >= (int)[menus count]) {
                    return 0;
                }
                NSMenu *menu = [menus objectAtIndex:parent];
                NSString *nsTitle = clayMenuString(title);

                if (kind == 1) {
                    [menu addItem:[NSMenuItem separatorItem]];
                    return 0;
                }

                if (kind == 2 || kind == 3) {
                    NSMenu *submenu = [[NSMenu alloc] initWithTitle:(kind == 2 && parent == 0) ? nsTitle : @""];
                    [submenu setDelegate:_clayMenuHandler];
                    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:nsTitle action:NULL keyEquivalent:@""];
                    [item setSubmenu:submenu];
                    [item setTag:id];
                    if (kind == 2) {
                        [item setEnabled:enabled ? YES : NO];
                    }
                    [menu addItem:item];
                    if (isDock) {
                        // No Services or Window menu in the dock menu
                    } else if (kind == 3) {
                        [NSApp setServicesMenu:submenu];
                    } else if (role == 7 && parent == 0) {
                        [NSApp setWindowsMenu:submenu];
                    }
                    int handle = (int)[menus count];
                    [menus addObject:submenu];
                    CLAY_MENU_RELEASE(item);
                    CLAY_MENU_RELEASE(submenu);
                    return kind == 2 ? handle : 0;
                }

                SEL selector;
                switch (role) {
                    case 1: selector = @selector(cut:); break;
                    case 2: selector = @selector(copy:); break;
                    case 3: selector = @selector(paste:); break;
                    case 4: selector = @selector(selectAll:); break;
                    // Undo and redo: no native text view to act on, like GPUI
                    default: selector = @selector(clayMenuItem:); break;
                }

                NSString *nsKey = clayMenuString(key);
                BOOL hasKey = [nsKey length] > 0;
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:nsTitle action:selector keyEquivalent:hasKey ? clayMenuKeyToNative(nsKey) : @""];
                if (hasKey) {
                    if ([item respondsToSelector:@selector(setAllowsAutomaticKeyEquivalentLocalization:)]) {
                        [item setAllowsAutomaticKeyEquivalentLocalization:NO];
                    }
                    [item setKeyEquivalentModifierMask:clayMenuModifierMask(modifiers)];
                }
                if (!_clayMenuUseResponderChain) {
                    [item setTarget:_clayMenuHandler];
                }
                if (checked) {
                    [item setState:NSControlStateValueOn];
                }
                [item setEnabled:enabled ? YES : NO];
                [item setTag:id];
                [menu addItem:item];
                CLAY_MENU_RELEASE(item);
                return 0;
            }
        }

        int menuBarAddItem(int parent, int kind, ::String title, ::String key, int modifiers, int role, int id, bool enabled, bool checked) {
            return clayMenuAddItem(_clayMenus, false, parent, kind, title, key, modifiers, role, id, enabled, checked);
        }

        void menuBarCommit() {
            @autoreleasepool {
                if (_clayMenus == nil || [_clayMenus count] == 0) {
                    return;
                }
                [NSApp setMainMenu:[_clayMenus objectAtIndex:0]];
                if (!_clayMenuWatchInstalled) {
                    _clayMenuWatchInstalled = true;
                    SDL_AddEventWatch(clayMenuKeyWatch, NULL);
                }
            }
        }

        int takeMenuKeyEquivalent(SDL_Event* event) {
            if (event == NULL || event->type != SDL_EVENT_KEY_DOWN || _clayMenuPendingCount == 0) {
                return -1;
            }
            return clayMenuTakePending(event->key.timestamp);
        }

        void clearMenuKeyEquivalents() {
            _clayMenuPendingCount = 0;
            _clayMenuKeyValid = NO;
            _clayMenuKeyEvent = NULL;
        }

        bool menuBarPerformItem(int id) {
            @autoreleasepool {
                NSMenu *owner = nil;
                NSMenuItem *item = clayMenuFindItem([NSApp mainMenu], id, &owner);
                if (item == nil || owner == nil) {
                    return false;
                }
                [owner performActionForItemAtIndex:[owner indexOfItem:item]];
                return true;
            }
        }

        int menuBarItemState(int id) {
            @autoreleasepool {
                NSMenu *owner = nil;
                NSMenuItem *item = clayMenuFindItem([NSApp mainMenu], id, &owner);
                if (item == nil || owner == nil) {
                    return -1;
                }
                [owner update];
                return ([item isEnabled] ? 1 : 0) | ([item state] == NSControlStateValueOn ? 2 : 0);
            }
        }

        ::String menuBarDescribe() {
            @autoreleasepool {
                NSMutableString *out = [NSMutableString string];
                NSMenu *main = [NSApp mainMenu];
                if (main != nil) {
                    // AppKit puts its own menu in the item given to setServicesMenu:
                    NSMenu *services = [NSApp servicesMenu];
                    NSMenu *servicesOwner = [services supermenu];
                    NSString *servicesTitle = @"-";
                    if (services != nil && servicesOwner != nil) {
                        NSInteger index = [servicesOwner indexOfItemWithSubmenu:services];
                        if (index >= 0) servicesTitle = [[servicesOwner itemAtIndex:index] title];
                    }
                    [out appendFormat:@"root %@ delegate=%d services=%@\n", [main isKindOfClass:[ClayMenuBar class]] ? @"clay" : @"other", [main delegate] == _clayMenuHandler ? 1 : 0, servicesTitle];
                    clayMenuDescribe(main, 1, out);
                }
                return ::String::create([out UTF8String]);
            }
        }

        int menuBarTestKeyEquivalent(::String chars, int modifiers, int timestamp) {
            @autoreleasepool {
                NSString *characters = clayMenuKeyToNative(clayMenuString(chars));
                NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown
                    location:NSZeroPoint
                    modifierFlags:clayMenuModifierMask(modifiers)
                    timestamp:[[NSProcessInfo processInfo] systemUptime]
                    windowNumber:0
                    context:nil
                    characters:characters
                    charactersIgnoringModifiers:characters
                    isARepeat:NO
                    keyCode:0];
                // As if SDL had just delivered this key down to the app
                _clayMenuKeyValid = YES;
                _clayMenuKeyEvent = (void *)event;
                _clayMenuKeyEventTime = [event timestamp];
                _clayMenuKeyTimestamp = (Uint64)timestamp;
                BOOL handled = [[NSApp mainMenu] performKeyEquivalent:event];
                _clayMenuKeyValid = NO;
                _clayMenuKeyEvent = NULL;
                int id = clayMenuTakePending((Uint64)timestamp);
                if (id >= 0) return id;
                return handled ? -2 : -1;
            }
        }

        void dockMenuBegin() {
            @autoreleasepool {
                if (_clayMenuHandler == nil) {
                    _clayMenuHandler = [[ClayMenuHandler alloc] init];
                }
                Class delegateClass = [[NSApp delegate] class];
                _clayMenuUseResponderChain = clayMenuGraftOnto(delegateClass);
                clayMenuGraftDockMenu(delegateClass);
                if (_clayDockMenus != nil) {
                    CLAY_MENU_RELEASE(_clayDockMenus);
                }
                _clayDockMenus = [[NSMutableArray alloc] init];
                // Like GPUI's dock menu, the application delegate is its
                // delegate: opening it runs the menu will open callback
                NSMenu *root = [[NSMenu alloc] initWithTitle:@""];
                [root setDelegate:_clayMenuHandler];
                [_clayDockMenus addObject:root];
                CLAY_MENU_RELEASE(root);
            }
        }

        int dockMenuAddItem(int parent, int kind, ::String title, ::String key, int modifiers, int role, int id, bool enabled, bool checked) {
            return clayMenuAddItem(_clayDockMenus, true, parent, kind, title, key, modifiers, role, id, enabled, checked);
        }

        void dockMenuCommit() {
            @autoreleasepool {
                if (_clayDockMenus == nil || [_clayDockMenus count] == 0) {
                    return;
                }
                NSMenu *root = [_clayDockMenus objectAtIndex:0];
                if (_clayDockMenu != nil) {
                    CLAY_MENU_RELEASE(_clayDockMenu);
                }
                // An empty dock menu shows only the system items
                _clayDockMenu = [root numberOfItems] > 0 ? root : nil;
                if (_clayDockMenu != nil) {
                    #if !__has_feature(objc_arc)
                    [_clayDockMenu retain];
                    #endif
                }
            }
        }

        ::String dockMenuDescribe() {
            @autoreleasepool {
                NSMutableString *out = [NSMutableString string];
                id delegate = [NSApp delegate];
                NSMenu *provided = nil;
                if (delegate != nil && [delegate respondsToSelector:@selector(applicationDockMenu:)]) {
                    provided = [delegate applicationDockMenu:NSApp];
                }
                [out appendFormat:@"dock installed=%d provided=%d delegate=%d\n",
                    _clayDockMenu != nil ? 1 : 0,
                    (provided != nil && provided == _clayDockMenu) ? 1 : 0,
                    (_clayDockMenu != nil && [_clayDockMenu delegate] == _clayMenuHandler) ? 1 : 0];
                if (_clayDockMenu != nil) {
                    clayMenuDescribe(_clayDockMenu, 1, out);
                }
                return ::String::create([out UTF8String]);
            }
        }

        bool dockMenuPerformItem(int id) {
            @autoreleasepool {
                if (_clayDockMenu == nil) {
                    return false;
                }
                NSMenu *owner = nil;
                NSMenuItem *item = clayMenuFindItem(_clayDockMenu, id, &owner);
                if (item == nil || owner == nil) {
                    return false;
                }
                [owner performActionForItemAtIndex:[owner indexOfItem:item]];
                return true;
            }
        }

    }
}
