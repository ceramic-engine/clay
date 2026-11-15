package;

import clay.StorageNames;

/**
 * Tests of `clay.StorageNames`. Run from the clay folder:
 * `haxe test/test-storage.hxml` (interpreter), or `haxe test/test-storage-js.hxml && node test/out/test-storage.js`.
 */
class StorageNamesTest {

    static var failures:Int = 0;

    static var checks:Int = 0;

    static function main() {

        testAppIdIsSplitAtItsLastDot();
        testAppIdWithoutDot();
        testAppIdSplitMatchesTheFormerCode();
        testStorageNameIsUsedUnsplit();
        testEmptyStorageNameIsIgnored();

        trace('StorageNamesTest: ' + checks + ' checks, ' + failures + ' failed');
        #if sys
        Sys.exit(failures > 0 ? 1 : 0);
        #elseif js
        js.Syntax.code("process.exit({0})", failures > 0 ? 1 : 0);
        #end

    }

    static function equals(expected:String, actual:String, what:String) {

        checks++;
        if (expected != actual) {
            failures++;
            trace('FAILED: ' + what + ' (expected "' + expected + '", got "' + actual + '")');
        }

    }

    /** What `SDLIO.appPathPrefs` did before `StorageNames` existed. */
    static function formerOrg(appId:String):String {

        var parts = appId.split('.');
        parts.pop();
        return parts.join('.');

    }

    static function formerApp(appId:String):String {

        var parts = appId.split('.');
        return parts.pop();

    }

    static function testAppIdIsSplitAtItsLastDot() {

        equals('com.example', StorageNames.prefOrg('com.example.game', null), 'org of com.example.game');
        equals('game', StorageNames.prefApp('com.example.game', null), 'app of com.example.game');
        equals('example', StorageNames.prefOrg('example.game', null), 'org of example.game');
        equals('game', StorageNames.prefApp('example.game', null), 'app of example.game');

    }

    static function testAppIdWithoutDot() {

        equals('', StorageNames.prefOrg('MyGame', null), 'org of MyGame');
        equals('MyGame', StorageNames.prefApp('MyGame', null), 'app of MyGame');

    }

    static function testAppIdSplitMatchesTheFormerCode() {

        for (appId in ['MyGame', 'a.b', 'com.example.game', 'trailing.', '.leading', 'a..b', '', '.', 'My Game', 'com.example.My Game']) {
            equals(formerOrg(appId), StorageNames.prefOrg(appId, null), 'org of "' + appId + '"');
            equals(formerApp(appId), StorageNames.prefApp(appId, null), 'app of "' + appId + '"');
            // An empty storage name changes nothing
            equals(formerOrg(appId), StorageNames.prefOrg(appId, ''), 'org of "' + appId + '" with an empty storage name');
            equals(formerApp(appId), StorageNames.prefApp(appId, ''), 'app of "' + appId + '" with an empty storage name');
        }

    }

    static function testStorageNameIsUsedUnsplit() {

        equals('', StorageNames.prefOrg('MyGame', 'com.example.game'), 'org with a storage name');
        equals('com.example.game', StorageNames.prefApp('MyGame', 'com.example.game'), 'app with a storage name');
        equals('', StorageNames.prefOrg('com.example.game', 'Other Folder'), 'org with a storage name and a dotted id');
        equals('Other Folder', StorageNames.prefApp('com.example.game', 'Other Folder'), 'app with a storage name and a dotted id');
        equals('com.example.game', StorageNames.prefApp('MyGame', '  com.example.game '), 'storage name is trimmed');

    }

    static function testEmptyStorageNameIsIgnored() {

        checks++;
        if (StorageNames.normalize(null) != null || StorageNames.normalize('') != null || StorageNames.normalize('   ') != null) {
            failures++;
            trace('FAILED: an empty storage name is no storage name');
        }
        equals('com.example', StorageNames.prefOrg('com.example.game', '   '), 'org with a blank storage name');
        equals('game', StorageNames.prefApp('com.example.game', '   '), 'app with a blank storage name');

    }

}
