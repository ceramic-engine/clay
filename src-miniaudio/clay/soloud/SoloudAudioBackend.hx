package clay.soloud;

import soloud.Soloud.SoloudBackends;
import soloud.Soloud;

#if clay_sdl
@:headerCode('#include <SDL3/SDL.h>')
#end

/**
 * Audio backend initializer for miniaudio/SDL.
 *
 * This class handles the platform-specific audio backend initialization
 * for SoLoud. By default it uses miniaudio, but can use SDL2 if the
 * `soloud_use_sdl` define is set.
 *
 * This file is located in src-miniaudio and included via classpath for
 * standard desktop/mobile builds. Other platforms can provide
 * their own SoloudAudioBackend.hx to use different audio backends.
 */
class SoloudAudioBackend {

    /**
     * Initializes the SoLoud audio backend.
     *
     * @param soloud The SoLoud instance to initialize
     * @return 0 on success, error code on failure
     */
    @:unreflective public static function init(soloud:Soloud):Int {
        #if (!soloud_use_miniaudio && soloud_use_sdl)
        return soloud.init(0, SDL2, 0, 64, 2);
        #else
        return soloud.init(0, MINIAUDIO, 0, 0, 2);
        #end
    }

}
