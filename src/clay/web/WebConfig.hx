package clay.web;

@:structInit
@:publicFields
class WebConfig {

    var windowId:String = 'app';

    var windowParent:js.html.Element = js.Browser.document.body;

    var preventDefaultContextMenu:Bool = #if clay_allow_default_context_menu false #else true #end;

    var preventDefaultMouseWheel:Bool = #if clay_allow_default_mouse_wheel false #else true #end;

    var preventDefaultTouches:Bool = #if clay_allow_default_touches false #else true #end;

    /**
     * Deliver smooth scrolling (wheel events in pixels: trackpads, smooth wheels) on the beat
     * of the frames when the browser dispatches it unevenly (Safari): see `clay.WheelResampler`.
     * Line and page deltas always go through untouched.
     */
    var wheelResampling:Bool = false;

    /**
     * Early tick on input (default `true`). While the app renders on demand and no continuous
     * rendering is going on (see `Clay.renderContinuous`), a discrete input event (key, text,
     * mouse button, touch down or up) is ticked and rendered at once from its DOM event
     * handler, at most once per refresh period, instead of at the next animation frame. An
     * app that draws every frame never ticks early. When `false`, every tick comes from an
     * animation frame. Read once at startup for the text listeners, then at each event.
     */
    var earlyTickOnInput:Bool = true;

    var preventDefaultKeys:Array<KeyCode> = [
        KeyCode.LEFT, KeyCode.RIGHT, KeyCode.UP, KeyCode.DOWN,
        KeyCode.BACKSPACE, KeyCode.TAB, KeyCode.DELETE, KeyCode.SPACE
    ];

    var mouseUseBrowserWindowEvents:Bool = true;

}
