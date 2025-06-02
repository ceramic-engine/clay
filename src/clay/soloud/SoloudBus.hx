package clay.soloud;

import soloud.Bus;

@:allow(clay.soloud.SoloudAudio)
class SoloudBus {

    @:unreflective public var bus(default, null):Bus;

    public function new() {
        this.bus = Bus.create();
    }

    public function destroy() {
        bus.destroy();
        bus = untyped __cpp__('NULL');
    }

}
