package clay.sdl;

@:structInit
@:publicFields
class SDLConfig {

    /** Custom uncaught error handler */
    public var uncaughtErrorHandler:(error:Dynamic)->Void = null;

    /**
     * Toggle auto window swap
     */
    public var autoSwap:Bool = true;
    
}
