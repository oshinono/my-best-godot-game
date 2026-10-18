#import <UIKit/UIKit.h>

#include "haptics.h"

// Генератор «щелчка» держим живым: prepare() перед серией тиков убирает
// задержку первого из них.
static UISelectionFeedbackGenerator *selection_generator = nil;

void GodotHaptics::_bind_methods() {
	ClassDB::bind_method(D_METHOD("prepare"), &GodotHaptics::prepare);
	ClassDB::bind_method(D_METHOD("selection"), &GodotHaptics::selection);
	ClassDB::bind_method(D_METHOD("impact", "strength"), &GodotHaptics::impact);

	BIND_ENUM_CONSTANT(STRENGTH_LIGHT);
	BIND_ENUM_CONSTANT(STRENGTH_MEDIUM);
	BIND_ENUM_CONSTANT(STRENGTH_HEAVY);
	BIND_ENUM_CONSTANT(STRENGTH_SOFT);
	BIND_ENUM_CONSTANT(STRENGTH_RIGID);
}

void GodotHaptics::prepare() {
	if (selection_generator == nil) {
		selection_generator = [UISelectionFeedbackGenerator new];
	}
	[selection_generator prepare];
}

void GodotHaptics::selection() {
	if (selection_generator == nil) {
		selection_generator = [UISelectionFeedbackGenerator new];
	}
	[selection_generator selectionChanged];
	// Готовим следующий тик заранее, иначе он запаздывает в быстрой серии.
	[selection_generator prepare];
}

void GodotHaptics::impact(int strength) {
	if (strength < STRENGTH_LIGHT || strength > STRENGTH_RIGID) {
		strength = STRENGTH_MEDIUM;
	}
	UIImpactFeedbackGenerator *generator =
			[[UIImpactFeedbackGenerator alloc] initWithStyle:(UIImpactFeedbackStyle)strength];
	[generator impactOccurred];
}

GodotHaptics::GodotHaptics() {
	prepare();
}

GodotHaptics::~GodotHaptics() {
	selection_generator = nil;
}
