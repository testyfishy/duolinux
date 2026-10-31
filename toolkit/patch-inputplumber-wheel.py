#!/usr/bin/env python3
"""Add axis→mouse-wheel support to InputPlumber.

InputPlumber can already translate a *button* into a wheel detent, but the axis
path (stick → wheel) returns NotImplemented, and the mouse target has no wheel
velocity state. This patch adds both, following the existing motion path so the
scroll rate is integrated over elapsed time rather than per input event.
"""
import pathlib
import sys

ROOT = pathlib.Path("/root/InputPlumber")
VALUE = ROOT / "src/input/event/value.rs"
MOUSE = ROOT / "src/input/target/mouse.rs"
CAP = ROOT / "src/config/capability_map.rs"


def edit(path: pathlib.Path, old: str, new: str) -> None:
    text = path.read_text()
    if old not in text:
        sys.exit(f"anchor not found in {path}: {old[:60]!r}")
    path.write_text(text.replace(old, new, 1))


# 1. capability config: speed and deadzone for wheel targets.
edit(
    CAP,
    """pub struct MouseWheelCapability {
    pub direction: Option<String>,
}""",
    """pub struct MouseWheelCapability {
    pub direction: Option<String>,
    /// Wheel velocity at full deflection, in hi-res units per second
    /// (120 units = one detent).
    #[serde(default)]
    pub speed: Option<f64>,
    /// Axis deadzone before any scrolling starts.
    #[serde(default)]
    pub deadzone: Option<f64>,
}""",
)

# 2. axis -> wheel translation.
edit(
    VALUE,
    """                                Mouse::Button(_) => self.translate_axis_to_button(source_config),
                                Mouse::Wheel => Err(TranslationError::NotImplemented),""",
    """                                Mouse::Button(_) => self.translate_axis_to_button(source_config),
                                Mouse::Wheel => {
                                    self.translate_axis_to_wheel(target_config)
                                }""",
)

edit(
    VALUE,
    "    fn translate_button_to_wheel(",
    """    /// Translate an axis (stick) into a wheel *velocity* in hi-res units per
    /// second. The mouse target integrates this over time, like pointer motion,
    /// so scroll speed is independent of the controller's report rate.
    fn translate_axis_to_wheel(
        &self,
        target_config: &CapabilityConfig,
    ) -> Result<InputValue, TranslationError> {
        let Some(mouse_config) = target_config.mouse.as_ref() else {
            return Err(TranslationError::InvalidTargetConfig(
                "No mouse config to translate axis to mouse wheel".to_string(),
            ));
        };
        let Some(wheel) = mouse_config.wheel.as_ref() else {
            return Err(TranslationError::InvalidTargetConfig(
                "No mouse wheel config found".to_string(),
            ));
        };

        let speed = wheel.speed.unwrap_or(1200.0);
        let deadzone = wheel.deadzone.unwrap_or(0.15);

        let (x, y) = match self {
            InputValue::Vector2 { x, y } => (*x, *y),
            InputValue::Vector3 { x, y, z: _ } => (*x, *y),
            _ => (None, None),
        };

        // Rescale past the deadzone so scrolling starts gradually instead of
        // jumping to the deadzone's edge value, then apply a mild curve for
        // fine control near the centre.
        let shape = |value: f64| -> f64 {
            if value.abs() <= deadzone {
                return 0.0;
            }
            let magnitude = (value.abs() - deadzone) / (1.0 - deadzone);
            let shaped = magnitude.powf(1.3);
            if value < 0.0 { -shaped } else { shaped }
        };

        // Stick up is negative Y; a negative REL_WHEEL scrolls content up, so
        // the axis sign is preserved.
        let vertical = y.map(|v| shape(v) * speed);
        let horizontal = x.map(|v| shape(v) * speed);

        let value = match wheel.direction.as_deref() {
            Some("horizontal") => InputValue::Vector2 { x: horizontal, y: None },
            Some("left") => InputValue::Vector2 {
                x: horizontal.filter(|v| *v < 0.0),
                y: None,
            },
            Some("right") => InputValue::Vector2 {
                x: horizontal.filter(|v| *v > 0.0),
                y: None,
            },
            // Default: vertical. Stick up produces a positive value, which the
            // mouse target turns into an upward wheel event.
            _ => InputValue::Vector2 {
                x: None,
                y: vertical.map(|v| -v),
            },
        };
        Ok(value)
    }

    fn translate_button_to_wheel(""",
)

# 3. mouse target: wheel velocity state, hi-res axes, integration.
edit(
    MOUSE,
    """pub struct MouseMotionState {
    mouse_remainder: (f64, f64),
    mouse_velocity: (f64, f64),
}""",
    """pub struct MouseMotionState {
    mouse_remainder: (f64, f64),
    mouse_velocity: (f64, f64),
    wheel_velocity: f64,
    wheel_remainder: f64,
}""",
)

edit(
    MOUSE,
    """                RelativeAxisCode::REL_WHEEL,
                RelativeAxisCode::REL_HWHEEL,
            ])?""",
    """                RelativeAxisCode::REL_WHEEL,
                RelativeAxisCode::REL_HWHEEL,
                RelativeAxisCode::REL_WHEEL_HI_RES,
                RelativeAxisCode::REL_HWHEEL_HI_RES,
            ])?""",
)

edit(
    MOUSE,
    """            self.update_state(event);
            return Ok(());
        }
""",
    """            self.update_state(event);
            return Ok(());
        }

        // Wheel velocity from an axis is kept and integrated in poll(), so the
        // scroll rate does not depend on how often the controller reports.
        if event.is_translated()
            && matches!(event.as_capability(), Capability::Mouse(Mouse::Wheel))
        {
            if let InputValue::Vector2 { x, y } = event.get_value() {
                if let Some(v) = y {
                    self.state.wheel_velocity = v;
                } else if let Some(v) = x {
                    self.state.wheel_velocity = v;
                }
            }
            return Ok(());
        }
""",
)

edit(
    MOUSE,
    """        Ok(vec![])
    }
}""",
    """        // Integrate the wheel velocity. 120 hi-res units make one detent, and
        // the legacy event is emitted alongside for consumers that ignore
        // hi-res wheel events.
        let wheel_delta = delta.as_secs_f64() * self.state.wheel_velocity;
        if wheel_delta != 0.0 {
            self.state.wheel_remainder += wheel_delta;
            let hi_res = self.state.wheel_remainder.trunc() as i32;
            self.state.wheel_remainder -= hi_res as f64;
            let mut events = Vec::new();
            if hi_res != 0 {
                events.push(InputEvent::new(
                    EventType::RELATIVE,
                    RelativeAxisCode::REL_WHEEL_HI_RES.0,
                    hi_res,
                ));
            }
            let notches = hi_res / 120;
            if notches != 0 {
                events.push(InputEvent::new(
                    EventType::RELATIVE,
                    RelativeAxisCode::REL_WHEEL.0,
                    notches,
                ));
            }
            if !events.is_empty() {
                if let Err(e) = self.device.emit(&events) {
                    return Err(e.to_string().into());
                }
            }
        }

        Ok(vec![])
    }
}""",
)

edit(
    MOUSE,
    """        self.state.mouse_velocity = (0.0, 0.0);
        self.state.mouse_remainder = (0.0, 0.0);""",
    """        self.state.mouse_velocity = (0.0, 0.0);
        self.state.mouse_remainder = (0.0, 0.0);
        self.state.wheel_velocity = 0.0;
        self.state.wheel_remainder = 0.0;""",
)

edit(
    MOUSE,
    """    AbsInfo, AbsoluteAxisCode, AttributeSet, BusType, InputEvent, InputId, KeyCode,
    RelativeAxisCode,""",
    """    AbsInfo, AbsoluteAxisCode, AttributeSet, BusType, EventType, InputEvent, InputId,
    KeyCode, RelativeAxisCode,""",
)

print("patch applied")
