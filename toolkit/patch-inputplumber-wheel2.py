#!/usr/bin/env python3
"""Remaining mouse-target edits for the InputPlumber wheel patch."""
import pathlib
import sys

MOUSE = pathlib.Path("/root/InputPlumber/src/input/target/mouse.rs")
text = MOUSE.read_text()
edits = 0


def sub(old: str, new: str) -> None:
    global text, edits
    if old not in text:
        sys.exit(f"anchor missing: {old[:70]!r}")
    text = text.replace(old, new, 1)
    edits += 1


sub(
    "                RelativeAxisCode::REL_HWHEEL,\n",
    "                RelativeAxisCode::REL_HWHEEL,\n"
    "                RelativeAxisCode::REL_WHEEL_HI_RES,\n"
    "                RelativeAxisCode::REL_HWHEEL_HI_RES,\n",
)

sub(
    """            self.update_state(event);
            return Ok(());
        }
""",
    """            self.update_state(event);
            return Ok(());
        }

        // Wheel velocity from an axis is integrated in poll(), so the scroll
        // rate does not depend on how often the controller reports.
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

sub(
    """        self.state.mouse_velocity = (0.0, 0.0);
        self.state.mouse_remainder = (0.0, 0.0);""",
    """        self.state.mouse_velocity = (0.0, 0.0);
        self.state.mouse_remainder = (0.0, 0.0);
        self.state.wheel_velocity = 0.0;
        self.state.wheel_remainder = 0.0;""",
)

sub(
    """    AbsInfo, AbsoluteAxisCode, AttributeSet, BusType, InputEvent, InputId, KeyCode,
    RelativeAxisCode,""",
    """    AbsInfo, AbsoluteAxisCode, AttributeSet, BusType, EventType, InputEvent, InputId,
    KeyCode, RelativeAxisCode,""",
)

sub(
    """        Ok(vec![])
    }
}""",
    """        // Integrate wheel velocity: 120 hi-res units make one detent, and the
        // legacy event is emitted alongside for consumers that ignore hi-res.
        let wheel_delta = delta.as_secs_f64() * self.state.wheel_velocity;
        if wheel_delta != 0.0 {
            self.state.wheel_remainder += wheel_delta;
            let hi_res = self.state.wheel_remainder.trunc() as i32;
            self.state.wheel_remainder -= hi_res as f64;
            let notches = hi_res / 120;
            let mut events = Vec::new();
            if hi_res != 0 {
                events.push(InputEvent::new(
                    EventType::RELATIVE,
                    RelativeAxisCode::REL_WHEEL_HI_RES.0,
                    hi_res,
                ));
            }
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

MOUSE.write_text(text)
print(f"mouse.rs: {edits} edits applied")
