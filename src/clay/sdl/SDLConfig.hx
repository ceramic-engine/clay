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

    /**
     * macOS: keep the momentum of trackpad and Magic Mouse scrolling (the
     * scroll events macOS sends after the fingers leave the trackpad),
     * through `SDL_HINT_MAC_SCROLL_MOMENTUM`. Read once, when SDL starts.
     */
    public var scrollMomentum:Bool = true;

    /**
     * macOS: deliver precise scrolling (trackpads, Magic Mouse) on the beat of the frames
     * when the system sends it unevenly against them. See `clay.WheelResampler`.
     */
    public var wheelResampling:Bool = false;
    
}
