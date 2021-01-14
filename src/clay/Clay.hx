package clay;

import clay.Config;
import clay.Types;

/**
 * Clay app
 */
class Clay {

/// Properties

    /**
     * Get Clay instance from anywhere with `Clay.app`
     */
    public static var app(default, null):Clay;

    /**
     * Clay config
     */
    public var config(default, null):Config;

    /**
     * Clay events handler
     */
    public var events(default, null):Events;

    /**
     * Clay io
     * (implementation varies depending on the target)
     */
    public var io(default, null):IO;

    /**
     * Clay assets
     */
    public var assets(default, null):Assets;

    /**
     * Clay input
     */
    public var input(default, null):Input;

    /**
     * Clay runtime
     * (implementation varies depending on the target)
     */
    public var runtime(default, null):Runtime;

    /** `true` if shut down has begun */
    public var shuttingDown:Bool = false;

    /** `true` if shut down has completed  */
    public var hasShutdown:Bool = false;

    /** The last known timestamp in seconds, or `-1` if not defined yet */
    public var timestamp:Float = -1;

    /**
     * Main window screen width
     */
    public var screenWidth(default, null):Int;

    /**
     * Main window screen height
     */
    public var screenHeight(default, null):Int;

    /**
     * Main window screen density (device pixel ratio)
     */
    public var screenDensity(default, null):Float;

    public var immediateShutdown:Bool = false;

    /** Whether or not we are frozen, ignoring events i.e backgrounded/paused */
    public var freeze(default, set):Bool = false;
    function set_freeze(freeze:Bool):Bool {
        this.freeze = freeze;
        if (freeze) {
            events.freeze();
        }
        else {
            events.unfreeze();
        }
        return freeze;
    }

    /** Whether or not the ready state has been reached */
    public var ready(default, null):Bool = false;

/// Lifecycle

    /**
     * Create a new Clay app
     * @param config Configuration to setup Clay app
     * @param events Events handler to get feedback from Clay
     */
    function new(configure:(config:Config)->Void, events:Events) {

        Clay.app = this;

        this.config = defaultConfig();
        configure(this.config);

        this.events = events;

        @:privateAccess io = new IO(this);
        Immediate.flush();

        @:privateAccess assets = new Assets(this);
        Immediate.flush();

        @:privateAccess input = new Input(this);
        Immediate.flush();

        @:privateAccess runtime = new Runtime(this);
        Immediate.flush();
        
        init();

    }

    function init() {

        Log.debug('Clay / init');

        io.init();
        Immediate.flush();

        input.init();
        Immediate.flush();

        runtime.init();
        Immediate.flush();

        Log.debug('Clay / ready');
        runtime.ready();
        Immediate.flush();

        timestamp = Runtime.timestamp();
        ready = true;

        updateScreen();

        events.ready();

        var shouldExit = runtime.run();
        if (shouldExit && !(hasShutdown || shuttingDown)) {
            shutdown();
        }

    }

    function shutdown() {

        if (shuttingDown) {
            Log.debug('Clay / shutdown() called again, already shutting down - ignoring');
            return;
        }
        
        if (hasShutdown) {
            throw 'Clay / calling shutdown() more than once is disallowed';
        }

        shuttingDown = true;

        io.shutdown();
        input.shutdown();

        runtime.shutdown(immediateShutdown);

        Log.debug('Clay / shutdown');

        hasShutdown = true;

    }

/// Internal events

    function emitQuit():Void {

        shutdown();

    }

    function emitTick():Void {

        if (freeze)
            return;

        #if clay_native
        if (windowInBackground && config.window.backgroundSleep != 0) {
            Sys.sleep(config.window.backgroundSleep);
        }
        #end

        Immediate.flush();

        updateScreen();

        if (!shuttingDown && ready) {
            var newTimestamp = Runtime.timestamp();
            var delta = newTimestamp - timestamp;
            timestamp = newTimestamp;

            events.tick(delta);
        }

    }

    function emitWindowEvent(type:WindowEventType, timestamp:Float, windowId:Int, x:Int, y:Int):Void {

        #if clay_native
        if (type == WindowEventType.FOCUS_LOST) {
            windowInBackground = true;
        } else if(type == WindowEventType.FOCUS_GAINED) {
            windowInBackground = false;
        }
        #end

        events.windowEvent(type, timestamp, windowId, x, y);

    }

    function emitAppEvent(type:AppEventType):Void {

        events.appEvent(type);

    }

/// Internal

    var windowInBackground = false;

    function defaultConfig():Config {

        return {
            runtime: Runtime.defaultConfig(),
            window: defaultWindowConfig(),
            render: defaultRenderConfig()
        };

    }

    function defaultWindowConfig():WindowConfig {

        var window:WindowConfig = {
            trueFullscreen: false,
            fullscreen: false,
            borderless: false,
            resizable: true,
            x: 0x1FFF0000,
            y: 0x1FFF0000,
            width: 960,
            height: 640,
            title: 'clay app',
            noInput: false,
            backgroundSleep: 1/15
        };

        #if (ios || android)
        window.fullscreen = true;
        window.borderless = true;
        #end

        return window;
        
    }

    function defaultRenderConfig():RenderConfig {

        return {
            depth: 0,
            stencil: 0,
            antialiasing: 0,
            redBits: 8,
            greenBits: 8,
            blueBits: 8,
            alphaBits: 8,
            defaultClear: { r:0, g:0, b:0, a:1 },
            #if clay_sdl
            opengl: {
            #if (ios || android)
                major: 2, minor: 0,
                profile: OpenGLProfile.GLES
            #else
                major: 0, minor: 0,
                profile: OpenGLProfile.COMPATIBILITY
            #end
            },
            #elseif clay_web
            webgl: {
                version: 1
            }
            #end
        };
        
    }

    function defaultRuntimeConfig():RuntimeConfig {

        #if clay_sdl
        return {
            uncaughtErrorHandler: null
        };
        #elseif clay_web
        return {
        };
        #end

    }

    function copyWindowConfig(config:WindowConfig):WindowConfig {

        return {
            fullscreen: config.fullscreen,
            trueFullscreen: config.trueFullscreen,
            resizable: config.resizable,
            borderless: config.borderless,
            x: config.x,
            y: config.y,
            width: config.width,
            height: config.height,
            title: '' + config.title,
            noInput: config.noInput,
            backgroundSleep: config.backgroundSleep
        };

    }

    function copyRenderConfig(config:RenderConfig):RenderConfig {

        return {
            depth: config.depth,
            stencil: config.stencil,
            antialiasing: config.antialiasing,
            redBits: config.redBits,
            greenBits: config.greenBits,
            blueBits: config.blueBits,
            alphaBits: config.alphaBits,
            defaultClear: { 
                r: config.defaultClear.r,
                g: config.defaultClear.g,
                b: config.defaultClear.b,
                a: config.defaultClear.a
            },
            #if clay_sdl
            opengl: {
                major: config.opengl.major,
                minor: config.opengl.minor,
                profile: config.opengl.profile
            }
            #elseif clay_web
            webgl: {
                version: config.webgl.version
            }
            #end
        }

    }

    function updateScreen():Void {

        screenDensity = app.runtime.windowDevicePixelRatio();
        screenWidth = Math.round(app.runtime.windowWidth() / screenDensity);
        screenHeight = Math.round(app.runtime.windowHeight() / screenDensity);

    }

}
