package clay;

/**
 * Names given to the platform when asking for the app storage folder
 * (`SDL_GetPrefPath(org, app)` on native targets).
 *
 * By default the app identifier is split at its last dot: `com.example.game`
 * gives the organisation `com.example` and the app `game`, so the folder is
 * `<prefs>/com.example/game/`. An optional storage name (define
 * `clay_app_storage_name`) is used as is, with no organisation: the storage
 * name `com.example.game` gives the folder `<prefs>/com.example.game/`.
 */
class StorageNames {

    /**
     * Returns the storage name to use, or `null` when there is none
     * (`null`, empty or only spaces).
     */
    public static function normalize(storageName:Null<String>):Null<String> {

        if (storageName == null)
            return null;

        final trimmed = StringTools.trim(storageName);
        return trimmed.length > 0 ? trimmed : null;

    }

    /**
     * Organisation part of the storage folder: empty with a storage name,
     * otherwise what comes before the last dot of the app identifier.
     */
    public static function prefOrg(appId:String, storageName:Null<String>):String {

        if (normalize(storageName) != null)
            return '';

        final dot = appId.lastIndexOf('.');
        return dot == -1 ? '' : appId.substring(0, dot);

    }

    /**
     * App part of the storage folder: the storage name when there is one,
     * otherwise what comes after the last dot of the app identifier.
     */
    public static function prefApp(appId:String, storageName:Null<String>):String {

        final name = normalize(storageName);
        if (name != null)
            return name;

        final dot = appId.lastIndexOf('.');
        return dot == -1 ? appId : appId.substring(dot + 1);

    }

}
