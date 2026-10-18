#include "core/config/engine.h"

#include "haptics.h"
#include "haptics_plugin.h"

static GodotHaptics *haptics_singleton = nullptr;

void haptics_init() {
	ClassDB::register_class<GodotHaptics>();
	haptics_singleton = memnew(GodotHaptics);
	Engine::get_singleton()->add_singleton(Engine::Singleton("HapticsIOS", haptics_singleton));
}

void haptics_deinit() {
	if (haptics_singleton) {
		memdelete(haptics_singleton);
		haptics_singleton = nullptr;
	}
}
