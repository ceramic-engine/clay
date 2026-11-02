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

    var preventDefaultKeys:Array<KeyCode> = [
        KeyCode.LEFT, KeyCode.RIGHT, KeyCode.UP, KeyCode.DOWN,
        KeyCode.BACKSPACE, KeyCode.TAB, KeyCode.DELETE, KeyCode.SPACE
    ];

    var mouseUseBrowserWindowEvents:Bool = true;

}
