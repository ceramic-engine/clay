package clay.web;

@:structInit
@:publicFields
class WebConfig {
    
    var windowId:String = 'app';

    var windowParent:js.html.Element = js.Browser.document.body;

    var preventDefaultContextMenu:Bool = true;

    var preventDefaultMouseWheel:Bool = true;

    var preventDefaultTouches:Bool = true;

    var preventDefaultKeys:Array<KeyCode> = [
        KeyCode.LEFT, KeyCode.RIGHT, KeyCode.UP, KeyCode.DOWN,
        KeyCode.BACKSPACE, KeyCode.TAB, KeyCode.DELETE, KeyCode.SPACE
    ];

    var mouseUseBrowserWindowEvents:Bool = true;

}
