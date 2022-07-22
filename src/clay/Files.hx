package clay;

import haxe.io.Path;
import sys.FileSystem;

class Files {

    public static function deleteRecursive(toDelete:String):Void {

        #if (cs || sys || node || nodejs || hxnodejs)

        if (!FileSystem.exists(toDelete)) return;

        if (FileSystem.isDirectory(toDelete)) {

            for (name in FileSystem.readDirectory(toDelete)) {

                var path = Path.join([toDelete, name]);
                if (FileSystem.isDirectory(path)) {
                    deleteRecursive(path);
                } else {
                    FileSystem.deleteFile(path);
                }
            }

            FileSystem.deleteDirectory(toDelete);

        }
        else {

            FileSystem.deleteFile(toDelete);

        }

        #else

        Log.warning('deleteRecursive() is not supported on this target');

        #end

    }

}