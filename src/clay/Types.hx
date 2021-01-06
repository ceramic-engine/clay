package clay;

/** A gamepad device event type */
enum abstract GamepadDeviceEventType(Int) from Int to Int {

    /** A unknown device event */
    var UNKNOWN             = 0;

    /** A device added event */
    var DEVICE_ADDED        = 1;

    /** A device removed event */
    var DEVICE_REMOVED      = 2;

    /** A device was remapped */
    var DEVICE_REMAPPED     = 3;

    inline function toString() {
        return switch(this) {
            case UNKNOWN:         'UNKNOWN';
            case DEVICE_ADDED:    'DEVICE_ADDED';
            case DEVICE_REMOVED:  'DEVICE_REMOVED';
            case DEVICE_REMAPPED: 'DEVICE_REMAPPED';
            case _:               '$this';
        }
    }

}

/** Input modifier state */
@:publicFields
class ModState {

    @:allow(clay)
    private inline function new() {}

    /** no modifiers are down */
    var none:Bool = false;

    /** left shift key is down */
    var lshift:Bool = false;

    /** right shift key is down */
    var rshift:Bool = false;

    /** left ctrl key is down */
    var lctrl:Bool = false;

    /** right ctrl key is down */
    var rctrl:Bool = false;

    /** left alt/option key is down */
    var lalt:Bool = false;

    /** right alt/option key is down */
    var ralt:Bool = false;

    /** left windows/command key is down */
    var lmeta:Bool = false;

    /** right windows/command key is down */
    var rmeta:Bool = false;

    /** numlock is enabled */
    var num:Bool = false;

    /** capslock is enabled */
    var caps:Bool = false;

    /** mode key is down */
    var mode:Bool = false;

    /** left or right ctrl key is down */
    var ctrl:Bool = false;

    /** left or right shift key is down */
    var shift:Bool = false;

    /** left or right alt/option key is down */
    var alt:Bool = false;

    /** left or right windows/command key is down */
    var meta:Bool = false;

    inline function toString() {

        var s = '{ "ModState":true ';

        if (none) return s + ', "none":true }';

        if (lshift) s += ', "lshift":true';
        if (rshift) s += ', "rshift":true';
        if (lctrl)  s += ', "lctrl":true';
        if (rctrl)  s += ', "rctrl":true';
        if (lalt)   s += ', "lalt":true';
        if (ralt)   s += ', "ralt":true';
        if (lmeta)  s += ', "lmeta":true';
        if (rmeta)  s += ', "rmeta":true';
        if (num)    s += ', "num":true';
        if (caps)   s += ', "caps":true';
        if (mode)   s += ', "mode":true';
        if (ctrl)   s += ', "ctrl":true';
        if (shift)  s += ', "shift":true';
        if (alt)    s += ', "alt":true';
        if (meta)   s += ', "meta":true';

        s += '}';

        return s;

    }

}

/** A text specific event event type */
enum abstract TextEventType(Int) from Int to Int {

    /** An unknown text event */
    var UNKNOWN = 0;

    /** An edit text typing event */
    var EDIT    = 1;

    /** An input text typing event */
    var INPUT   = 2;

    inline function toString() {
        return switch(this) {
            case UNKNOWN: 'UNKNOWN';
            case EDIT:    'EDIT';
            case INPUT:   'INPUT';
            case _:       '$this';
        }
    }

}

enum abstract WindowEventType(Int) from Int to Int {

    /** An unknown window event */
    var UNKNOWN          = 0;

    /** The window is shown */
    var SHOWN            = 1;

    /** The window is hidden */
    var HIDDEN           = 2;

    /** The window is exposed */
    var EXPOSED          = 3;

    /** The window is moved */
    var MOVED            = 4;

    /** The window is resized, by the user or code. */
    var RESIZED          = 5;

    /** The window is resized, by the OS or internals. */
    var SIZE_CHANGED     = 6;

    /** The window is minimized */
    var MINIMIZED        = 7;

    /** The window is maximized */
    var MAXIMIZED        = 8;

    /** The window is restored */
    var RESTORED         = 9;

    /** The window is entered by a mouse */
    var ENTER            = 10;

    /** The window is left by a mouse */
    var LEAVE            = 11;

    /** The window has gained focus */
    var FOCUS_GAINED     = 12;

    /** The window has lost focus */
    var FOCUS_LOST       = 13;

    /** The window is being closed/hidden */
    var CLOSE            = 14;

    inline function toString() {
        return switch(this) {
            case UNKNOWN:       'UNKNOWN';
            case SHOWN:         'SHOWN';
            case HIDDEN:        'HIDDEN';
            case EXPOSED:       'EXPOSED';
            case MOVED:         'MOVED';
            case RESIZED:       'RESIZED';
            case SIZE_CHANGED:  'SIZE_CHANGED';
            case MINIMIZED:     'MINIMIZED';
            case MAXIMIZED:     'MAXIMIZED';
            case RESTORED:      'RESTORED';
            case ENTER:         'ENTER';
            case LEAVE:         'LEAVE';
            case FOCUS_GAINED:  'FOCUS_GAINED';
            case FOCUS_LOST:    'FOCUS_LOST';
            case CLOSE:         'CLOSE';
            case _:             '$this';
        }
    }

}

enum abstract AppEventType(Int) from Int to Int {

    /** An unknown app event */
    var UNKNOWN                = 0;

    /** An system terminating event, called by the OS (mobile specific) */
    var TERMINATING            = 11;

    /** An system low memory event, clear memory if you can. Called by the OS (mobile specific) */
    var LOW_MEMORY             = 12;

    /** An event for just before the app enters the background, called by the OS (mobile specific) */
    var WILL_ENTER_BACKGROUND  = 13;

    /** An event for when the app enters the background, called by the OS (mobile specific) */
    var DID_ENTER_BACKGROUND   = 14;

    /** An event for just before the app enters the foreground, called by the OS (mobile specific) */
    var WILL_ENTER_FOREGROUND  = 15;
    
    /** An event for when the app enters the foreground, called by the OS (mobile specific) */
    var DID_ENTER_FOREGROUND   = 16;

    inline function toString() {
        return switch(this) {
            case UNKNOWN:               'UNKNOWN';
            case TERMINATING:           'TERMINATING';
            case LOW_MEMORY:            'LOW_MEMORY';
            case WILL_ENTER_BACKGROUND: 'WILL_ENTER_BACKGROUND';
            case DID_ENTER_BACKGROUND:  'DID_ENTER_BACKGROUND';
            case WILL_ENTER_FOREGROUND: 'WILL_ENTER_FOREGROUND';
            case DID_ENTER_FOREGROUND:  'DID_ENTER_FOREGROUND';
            case _:                     '$this';
        }
    }

}
