package clay;

/**
 * An item of the application menu bar given to `runtime.setMenuBar`
 * (native menu bar on macOS).
 *
 * - `kind`: 0 action, 1 separator, 2 submenu (`items`), 3 the system's
 *   Services submenu.
 * - `key`: the shortcut key shown and matched by the system: a single
 *   character, or a key name (`space`, `backspace`, `escape`, `up`, `down`,
 *   `left`, `right`, `pageup`, `pagedown`, `home`, `end`, `delete`,
 *   `insert`, `f1` to `f35`); `null` or empty for none.
 * - `modifiers`: 1 shift, 2 control, 4 alt (option), 8 meta (command).
 * - `role`: 0 none, 1 cut, 2 copy, 3 paste, 4 select all, 5 undo, 6 redo
 *   (actions), 7 the Window menu (top level submenus).
 * - `id`: reported back by `events.menuAction`, `events.menuKeyEquivalent`
 *   and `events.menuItemEnabled`.
 */
typedef MenuItemSpec = {

    var id:Int;

    var kind:Int;

    var title:String;

    @:optional var key:String;

    var modifiers:Int;

    var role:Int;

    var enabled:Bool;

    var checked:Bool;

    @:optional var items:Array<MenuItemSpec>;

}
