package clay;

import clay.Config;
import clay.Types;
import haxe.Json;

using StringTools;

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
     * Clay audio
     */
    public var audio(default, null):Audio;

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
    public var shuttingDown(default, null):Bool = false;

    /** `true` if shut down has completed  */
    public var hasShutdown(default, null):Bool = false;

    /** The last known timestamp in seconds, or `-1` if not defined yet */
    public var timestamp(default, null):Float = -1;

    /**
     * App identifier
     */
    public var appId(default, null):String;

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

    /**
     * Shared background queue
     */
    public var backgroundQueue(default, null):BackgroundQueue;

    public var immediateShutdown:Bool = false;

    /**
     * Used for update loop and update rate
     */
    var nextTick:Float = 0;

    /** Whether or not we are frozen, ignoring events i.e backgrounded/paused */
    public var freeze(default, set):Bool = false;
    function set_freeze(freeze:Bool):Bool {
        this.freeze = freeze;
        if (freeze) {
            events.freeze();
            audio.suspend();
        }
        else {
            events.unfreeze();
            audio.resume();
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

        Runner.init();

        extractAppId();

        this.config = defaultConfig();
        configure(this.config);

        this.events = events;

        @:privateAccess io = new IO(this);
        Immediate.flush();

        @:privateAccess assets = new Assets(this);
        Immediate.flush();

        @:privateAccess audio = new Audio(this);
        Immediate.flush();

        @:privateAccess input = new Input(this);
        Immediate.flush();

        @:privateAccess runtime = new Runtime(this);
        Immediate.flush();

        backgroundQueue = new BackgroundQueue();

        init();

    }

    function init() {

        Log.debug('Clay / init');

        io.init();
        Immediate.flush();

        audio.init();
        Immediate.flush();

        input.init();
        Immediate.flush();

        runtime.init();
        Immediate.flush();

        Log.debug('Clay / ready');
        runtime.ready();
        Immediate.flush();

        audio.ready();
        Immediate.flush();

        timestamp = Runtime.timestamp();
        ready = true;
        nextTick = timestamp;

        updateScreen();

        events.ready();

        var shouldExit = runtime.run();
        if (shouldExit && !(hasShutdown || shuttingDown)) {
            shutdown();
        }

    }

    public function shutdown() {

        if (shuttingDown) {
            Log.debug('Clay / shutdown() called again, already shutting down - ignoring');
            return;
        }

        if (hasShutdown) {
            throw 'Clay / calling shutdown() more than once is disallowed';
        }

        shuttingDown = true;

        io.shutdown();
        audio.shutdown();
        input.shutdown();

        runtime.shutdown(immediateShutdown);

        Log.debug('Clay / shutdown');

        hasShutdown = true;

    }

/// Internal events

    function emitQuit():Void {

        shutdown();

    }

    function shouldUpdate(newTimestamp:Float):Bool {

        // Cap update rate if needed
        if (config.updateRate > 0) {
            if (newTimestamp < nextTick) {
                return false;
            }

            while (nextTick <= newTimestamp) {
                nextTick += config.updateRate;
            }
        }
        else {
            nextTick = newTimestamp;
        }

        return true;

    }

    function emitTick(newTimestamp:Float):Void {

        if (freeze)
            return;

        #if clay_native
        if (windowInBackground && config.window.backgroundSleep != 0) {
            Sys.sleep(config.window.backgroundSleep);
        }
        #end

        Runner.tick();

        Immediate.flush();

        updateScreen();

        if (!shuttingDown && ready) {
            var delta = newTimestamp - timestamp;
            timestamp = newTimestamp;

            audio.tick(delta);
            events.tick(delta);
        }

    }

    function emitRender():Void {

        if (freeze)
            return;

        if (!shuttingDown && ready) {
            events.render();
        }

    }

    function emitWindowEvent(type:WindowEventType, timestamp:Float, windowId:Int, x:Int, y:Int):Void {

        #if clay_native
        switch type {
            case MINIMIZED:
                audio.suspend();
            case RESTORED:
                audio.resume();
            case FOCUS_GAINED:
                windowInBackground = false;
            case FOCUS_LOST:
                windowInBackground = true;
            case _:
        }
        #end

        events.windowEvent(type, timestamp, windowId, x, y);

    }

    function emitAppEvent(type:AppEventType):Void {

        events.appEvent(type);

    }

/// Internal

    var windowInBackground = false;

    function extractAppId():Void {

        var rawAppId:String = Macros.definedValue('clay_app_id');
        if (rawAppId.startsWith('"')) {
            this.appId = Json.parse(rawAppId);
        }
        else {
            this.appId = rawAppId;
        }

    }

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
