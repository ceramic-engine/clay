package clay;

import clay.graphics.Color;

#if clay_web
typedef RuntimeConfig = clay.web.WebConfig;
#elseif clay_sdl
typedef RuntimeConfig = clay.sdl.SDLConfig;
#end

/** Config specific to the rendering context that would be used when creating windows */
@:structInit
@:publicFields
class RenderConfig {

    /** Request the number of depth bits for the rendering context.
        A value of 0 will not request a depth buffer. default: 0 */
    var depth:Int = 0;

    /** Request the number of stencil bits for the rendering context.
        A value of 0 will not request a stencil buffer. default: 0 */
    var stencil:Int = 0;

    /** A value of `0`, `2`, `4`, `8` or other valid system value.
        On WebGL contexts this value is true or false, bigger than 0 being true.
        On native contexts this value sets the MSAA typically.
        default webgl: 1 (enabled)
        default: 0 */
    var antialiasing:Int = 0;

    /** Request a specific number of red bits for the rendering context.
        Unless you need to change this, don't. default: 8 */
    var redBits:Int = 8;
    /** Request a specific number of green bits for the rendering context.
        Unless you need to change this, don't. default: 8 */
    var greenBits:Int = 8;
    /** Request a specific number of blue bits for the rendering context.
        Unless you need to change this, don't. default: 8 */
    var blueBits:Int = 8;
    /** Request a specific number of alpha bits for the rendering context.
        Unless you need to change this, don't. default: 8 */
    var alphaBits:Int = 8;

    /** A color value that when creating the window, the window backbuffer will be cleared to.
        A framework above clay can also use this for default clear color if desired.
        The values are specified as 0..1. default: black, 0,0,0,1  */
    var defaultClear:Color = { r: 0, g: 0, b: 0, a: 1 };

    /** If applicable on the current platform, enables vsync */
    var vsync:Bool = #if clay_no_vsync false #else true #end;

    /**
     * Number of drawables of the Metal layer the app renders to (macOS, ANGLE Metal):
     * 2 or 3. macOS gives 3 by default: with vsync, a frame then waits behind two older ones
     * before it is shown. With 2 it waits behind one. Ignored on other targets, iOS
     * included (its loop is a display link callback, which two drawables slow down to
     * half the frame rate). default: 2
     */
    var maxDrawables:Int = 2;

    /**
     * Wait for the drawable at the start of the frame, before the input is read, instead of
     * in the first draw call after the update: what is drawn is then one vsync more recent.
     * Only where the runtime is compiled with `clay_wait_drawable_first` (macOS and iOS),
     * ignored elsewhere. Can be changed while running. default: true
     *
     * A frame that starts at the drawable return has `period - framePacingFloor` for its work
     * (the deadline). When frames take longer, waiting first costs a whole period per frame,
     * so the runtime stops waiting first while frames are slow, see the settings below.
     */
    var waitDrawableFirst:Bool = true;

    /**
     * Frames in a row whose work exceeds the deadline (`period - framePacingFloor`) that stop
     * the wait for the drawable first. One isolated long frame changes nothing.
     * Unit: frames. default: 3
     */
    var waitDrawableFirstSlowFrames:Int = 3;

    /**
     * Frames in a row whose work is within the deadline (`period - framePacingFloor`) that
     * resume the wait for the drawable first. Doubled each time waiting first is stopped
     * again less than a second after it resumed (up to `waitDrawableFirstBackoffCap`), halved
     * after each 5 seconds without a stop. Unit: frames. default: 8
     */
    var waitDrawableFirstFastFrames:Int = 8;

    /**
     * Longest run of fast frames needed to resume the wait for the drawable first, once
     * doubled by the backoff. Unit: seconds of frames (2.0 is 120 frames at 60 Hz). default: 2.0
     */
    var waitDrawableFirstBackoffCap:Float = 2.0;

    /**
     * Margin frame pacing: after the drawable wait returned (a vsync), the loop sleeps until
     * `next vsync - margin` before it reads the input, so the input shown is as recent as
     * possible. `margin = framePacingFloor + framePacingMultiple x worst recent work`.
     * Engages only when the margin fits in the period, with exactly the conditions of
     * `clay.FramePacer`. Needs the wait for the drawable first, so it only exists where
     * `clay_wait_drawable_first` is compiled and the runtime owns its loop (macOS), ignored
     * elsewhere. Can be changed while running. default: true
     */
    var framePacing:Bool = true;

    /**
     * Fixed part of the pacing margin: the lead the compositor needs before a vsync, plus
     * what is not measured (GPU time after the submit, wake up jitter). It is also what
     * defines the deadline of a frame (`period - framePacingFloor`), used by the wait for the
     * drawable first. Unit: seconds. default: 0.004
     */
    var framePacingFloor:Float = 0.004;

    /**
     * The worst recent work is multiplied by this in the pacing margin. Pacing engages only
     * when `framePacingFloor + framePacingMultiple x worst work <= period`: at 60 Hz with the
     * defaults, up to 6.3 ms of work per frame. It does not apply to the wait for the drawable
     * first. default: 2.0
     */
    var framePacingMultiple:Float = 2.0;

    /**
     * Largest number of frames over which the worst work is taken for the pacing margin.
     * A frame over the deadline counts as one full period and keeps pacing off while it is
     * in the window. The window used starts at `framePacingMinWindow` and doubles, up to
     * this, each time pacing fails less than a second after it engaged again.
     * Unit: frames, not time (120 is 2 seconds at 60 Hz, 1 second at 120 Hz). default: 120
     */
    var framePacingWindow:Int = 120;

    /**
     * Smallest number of frames over which the worst work is taken for the pacing margin:
     * after a long frame, pacing is tried again this many frames later (plus its lock of 5
     * consistent vsync signals). The window halves back towards this after each 5 seconds
     * without a frame over the deadline or a paced miss. Unit: frames. default: 8
     */
    var framePacingMinWindow:Int = 8;

    #if clay_web

    /** WebGL render context specific settings */
    var webgl:RenderConfigWebGL = null;

    #elseif clay_sdl

    /** OpenGL render context specific settings */
    var opengl:RenderConfigOpenGL = null;

    #end

}

#if clay_web

/** Config specific to a WebGL rendering context.
    See: https://www.khronos.org/registry/webgl/specs/latest/1.0/#WEBGLCONTEXTATTRIBUTES */
@:structInit
@:publicFields
class RenderConfigWebGL {

    /** The WebGL version to request. default: 1 */
    var version:Int = 1;

    /** If the value is true, the drawing buffer has an alpha channel for the
        purposes of performing OpenGL destination alpha operations and
        compositing with the page. If the value is false, no alpha buffer is available.
        clay default: false
        webgl default: true */
    var alpha:Bool = false;

    /** If the value is true, the drawing buffer has a depth buffer of at least 16 bits.
        If the value is false, no depth buffer is available.
        clay default: uses render config depth flag
        webgl default: true */
    var depth:Bool = true;

    /** If the value is true, the drawing buffer has a stencil buffer of at least 8 bits.
        If the value is false, no stencil buffer is available.
        clay default: uses render config stencil flag
        webgl default: false */
    var stencil:Bool = false;

    /** If the value is true and the implementation supports antialiasing the drawing buffer
        will perform antialiasing using its choice of technique (multisample/supersample) and quality.
        If the value is false or the implementation does not support
        antialiasing, no antialiasing is performed
        clay default: uses render config antialias flag
        webgl default: true */
    var antialias:Bool = true;

    /** If the value is true the page compositor will assume the drawing buffer contains colors with premultiplied alpha.
        If the value is false the page compositor will assume that colors in the drawing buffer are not premultiplied.
        This flag is ignored if the alpha flag is false.
        clay default: false
        webgl default: true */
    var premultipliedAlpha:Bool = false;

    /** If false, once the drawing buffer is presented as described in theDrawing Buffer section,
        the contents of the drawing buffer are cleared to their default values. All elements of the
        drawing buffer (color, depth and stencil) are cleared. If the value is true the buffers will
        not be cleared and will preserve their values until cleared or overwritten by the author.
        On some hardware setting the preserveDrawingBuffer flag to true can have significant performance implications.
        clay default: uses webgl default
        webgl default: false */
    var preserveDrawingBuffer:Bool = false;

    /** Provides a hint to the implementation suggesting that, if possible, it creates a context
        that optimizes for power consumption over performance. For example, on hardware that has more
        than one GPU, it may be the case that one of them is less powerful but also uses less power.
        An implementation may choose to, and may have to, ignore this hint.
        clay default: uses webgl default
        webgl default: false */
    var preferLowPowerToHighPerformance:Bool = false;

    /** If the value is true, context creation will fail if the implementation determines that the
        performance of the created WebGL context would be dramatically lower than that of a native
        application making equivalent OpenGL calls.
        clay default: uses webgl default
        webgl default: false */
    var failIfMajorPerformanceCaveat:Bool = false;

}

#elseif clay_sdl

/** A type of OpenGL context profile to request. see RenderConfigOpenGL for info */
enum abstract OpenGLProfile(Int)
    from Int to Int {

    var COMPATIBILITY = 0;

    var CORE = 1;

    var GLES = 2;

    inline function toString() {
        return switch(this) {
            case COMPATIBILITY: 'COMPATIBILITY';
            case CORE:          'CORE';
            case GLES:          'GLES';
            case _:             '$this';
        }
    }

}

/** Config specific to an OpenGL rendering context.
    Note that these are hints to the system,
    you must always check the values after initializing
    for what you actually received. The OS/driver decides. */
@:structInit
@:publicFields
class RenderConfigOpenGL {

    /** The major OpenGL version to request */
    var major:Int = 2;

    /** The minor OpenGL version to request */
    var minor:Int = 0;

    /** The OpenGL context profile to request */
    var profile:OpenGLProfile = OpenGLProfile.GLES;

}

#end

/** Window configuration information for creating windows */
@:structInit
@:publicFields
class WindowConfig {

    /** create in fullscreen, default: false, `mobile` true */
    var fullscreen:Bool = false;

    /** If false, the users native window/desktop resolution will be used instead of the specified window size. default: false
        On native, changing the users video mode is less than ideal, so trueFullscreen is commonly discouraged. */
    var trueFullscreen:Bool = false;

    /** allow the window to be resized, default: true */
    var resizable:Bool = true;

    /** create as a borderless window, default: false */
    var borderless:Bool = false;

    /** window x at creation. Leave this alone to use the OS default. */
    var x:Int = 0;

    /** window y at creation. Leave this alone to use the OS default. */
    var y:Int = 0;

    /** window width at creation, default: 960 */
    var width:Int = 960;

    /** window height at creation, default: 640 */
    var height:Int = 640;

    /** window title, default: 'clay app' */
    var title:String = null;

    /** minimum width the user can give to the window, in logical units (0: no minimum). default: 0 */
    var minWidth:Int = 0;

    /** minimum height the user can give to the window, in logical units (0: no minimum). default: 0 */
    var minHeight:Int = 0;

    /** create the window hidden: it is shown by `runtime.showWindowAfterNextFrame()`
        (after a frame was presented) or `runtime.showWindow()`. default: false */
    var startsHidden:Bool = false;

    /** title bar of the window on macOS: 0 the title bar of the system, 1 overlay
        (the content takes the whole window, transparent title bar, hidden title). default: 0 */
    var titleBarStyle:Int = 0;

    /** with the overlay title bar on macOS: distance from the left edge of the window to
        the left of the close button, in points (negative: the place the system gives). default: -1 */
    var titleBarButtonsX:Float = -1;

    /** with the overlay title bar on macOS: distance from the top edge of the window to
        the top of the window buttons, in points (negative: the place the system gives). default: -1 */
    var titleBarButtonsY:Float = -1;

    /** disables input arriving at/from this window. default: false */
    var noInput:Bool = false;

    /** Time in seconds to sleep when in the background.
        Setting this to zero disables the behavior.
        This has no effect on the web target,
        as there is no concept of sleep there (and browsers usually throttle background tabs).
        Higher sleep times (i.e 1/10 or 1/30) use less cpu. default: 1/15 */
    var backgroundSleep:Float = 1.0 / 15;

}

@:structInit
@:publicFields
class Config {

    /**
     * The window config for the default window. default: see `WindowConfig` docs
     */
    var window:WindowConfig = null;

    /**
     * The render config that specifies rendering and context backend specifics.
     */
    var render:RenderConfig = null;

    /**
     * The runtime specific config
     */
    var runtime:RuntimeConfig = null;

    /**
     * If this is non zero, updates will be forced to this rate
     */
    var updateRate:Float = 0;

    /**
     * The most ticks per second while the app is at rest or its window in the background
     * (see `clay.IdleThrottle`). Only meaningful for an app that sets `Clay.renderSkipped`
     * when it draws nothing. Can be changed at any time.
     * default: 0 (no cap: the loop behaves as without it)
     */
    var idleUpdateRate:Float = 0;

    /**
     * With `idleUpdateRate`: seconds at the normal rate after the last activity (input,
     * window event, work posted from another thread, continuous render). Can be changed at
     * any time. default: 0.5
     */
    var idleDelay:Float = 0.5;

    /**
     * Whether audio is initialized. When false, no audio device, audio
     * thread or web audio context is created (native: neither SoLoud's
     * backend nor SDL's audio subsystem starts), `app.audio.active` stays
     * false and `app.audio.enabled` is false. Read once, at startup.
     * default: true
     */
    var audio:Bool = true;

}
