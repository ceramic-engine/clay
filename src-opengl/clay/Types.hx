package clay;

import clay.opengl.GL;
import clay.opengl.GL.GLBuffer;
import clay.opengl.GL.GLFramebuffer;
import clay.opengl.GL.GLProgram;
import clay.opengl.GL.GLRenderbuffer;
import clay.opengl.GL.GLShader;
import clay.opengl.GL.GLTexture;
import clay.opengl.GL.GLUniformLocation;
import clay.opengl.GLGraphicsDriver;

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

    /** The window entered fullscreen */
    var ENTER_FULLSCREEN = 15;

    /** The window exited fullscreen */
    var EXIT_FULLSCREEN  = 16;

    inline function toString() {
        return switch(this) {
            case UNKNOWN:          'UNKNOWN';
            case SHOWN:            'SHOWN';
            case HIDDEN:           'HIDDEN';
            case EXPOSED:          'EXPOSED';
            case MOVED:            'MOVED';
            case RESIZED:          'RESIZED';
            case SIZE_CHANGED:     'SIZE_CHANGED';
            case MINIMIZED:        'MINIMIZED';
            case MAXIMIZED:        'MAXIMIZED';
            case RESTORED:         'RESTORED';
            case ENTER:            'ENTER';
            case LEAVE:            'LEAVE';
            case FOCUS_GAINED:     'FOCUS_GAINED';
            case FOCUS_LOST:       'FOCUS_LOST';
            case CLOSE:            'CLOSE';
            case ENTER_FULLSCREEN: 'ENTER_FULLSCREEN';
            case EXIT_FULLSCREEN:  'EXIT_FULLSCREEN';
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

// For now, all targets are using GL api

/** Cross-platform texture identifier */
typedef TextureId = GLTexture;

/** Cross-platform render target */
typedef RenderTarget = GLGraphicsDriver_RenderTarget;

/** Cross-platform compiled shader program */
typedef GpuShader = GLGraphicsDriver_GpuShader;

/** Cross-platform uniform location handle */
typedef UniformLocation = GLUniformLocation;

/** Cross-platform framebuffer handle */
typedef Framebuffer = GLFramebuffer;

/** Cross-platform renderbuffer handle */
typedef Renderbuffer = GLRenderbuffer;

/** Cross-platform shader handle (vertex or fragment) */
typedef ShaderHandle = GLShader;

/** Cross-platform shader program handle */
typedef ProgramHandle = GLProgram;

/** Cross-platform GPU buffer handle */
typedef BufferHandle = GLBuffer;

enum abstract TextureFormat(Int) from Int to Int {

    var RGB = GL.RGB;

    var RGBA = GL.RGBA;

}

// Only 2D textures are supported at the moment
enum abstract TextureType(Int) from Int to Int {

    var TEXTURE_2D = GL.TEXTURE_2D;

}

enum abstract TextureDataType(Int) from Int to Int {

    var UNSIGNED_BYTE = GL.UNSIGNED_BYTE;

}

enum abstract TextureFilter(Int) from Int to Int {

    var NEAREST = GL.NEAREST;
    var LINEAR = GL.LINEAR;
    var NEAREST_MIPMAP_NEAREST = GL.NEAREST_MIPMAP_NEAREST;
    var LINEAR_MIPMAP_NEAREST = GL.LINEAR_MIPMAP_NEAREST;
    var NEAREST_MIPMAP_LINEAR = GL.NEAREST_MIPMAP_LINEAR;
    var LINEAR_MIPMAP_LINEAR = GL.LINEAR_MIPMAP_LINEAR;

}

enum abstract TextureWrap(Int) from Int to Int {

    var CLAMP_TO_EDGE = GL.CLAMP_TO_EDGE;
    var REPEAT = GL.REPEAT;
    var MIRRORED_REPEAT = GL.MIRRORED_REPEAT;

}

enum abstract BlendMode(Int) from Int to Int {

    var ZERO                    = GL.ZERO;
    var ONE                     = GL.ONE;
    var SRC_COLOR               = GL.SRC_COLOR;
    var ONE_MINUS_SRC_COLOR     = GL.ONE_MINUS_SRC_COLOR;
    var SRC_ALPHA               = GL.SRC_ALPHA;
    var ONE_MINUS_SRC_ALPHA     = GL.ONE_MINUS_SRC_ALPHA;
    var DST_ALPHA               = GL.DST_ALPHA;
    var ONE_MINUS_DST_ALPHA     = GL.ONE_MINUS_DST_ALPHA;
    var DST_COLOR               = GL.DST_COLOR;
    var ONE_MINUS_DST_COLOR     = GL.ONE_MINUS_DST_COLOR;
    var SRC_ALPHA_SATURATE      = GL.SRC_ALPHA_SATURATE;

}

#if clay_sdl
typedef FileHandle = clay.sdl.SDLIO.FileHandle;
typedef FileSeek = clay.sdl.SDLIO.FileSeek;
#end
