#ifndef GODOT_HAPTICS_IMPLEMENTATION_H
#define GODOT_HAPTICS_IMPLEMENTATION_H

#include "core/version.h"

#if VERSION_MAJOR == 4
#include "core/object/class_db.h"
#else
#include "core/object.h"
#endif

// Обёртка над системными генераторами тактильного отклика iOS.
// Синглтон регистрируется под именем "HapticsIOS" (см. haptics_plugin.cpp).
class GodotHaptics : public Object {
	GDCLASS(GodotHaptics, Object);

	static void _bind_methods();

public:
	// Значения совпадают с UIImpactFeedbackStyle, чтобы не мапить их вручную.
	enum Strength {
		STRENGTH_LIGHT = 0,
		STRENGTH_MEDIUM = 1,
		STRENGTH_HEAVY = 2,
		STRENGTH_SOFT = 3,
		STRENGTH_RIGID = 4,
	};

	void prepare();
	void selection();
	void impact(int strength);

	GodotHaptics();
	~GodotHaptics();
};

VARIANT_ENUM_CAST(GodotHaptics::Strength)

#endif // GODOT_HAPTICS_IMPLEMENTATION_H
