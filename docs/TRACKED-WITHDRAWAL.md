# Tracked withdrawal integration

Tracked fighting vehicles should keep their frontal hull arc roughly toward the last known
contact while reversing out of immediate exposure. Wheeled vehicles retain native forward escape.
A bounded initial reverse leg is implemented in the working candidate; physical acceptance is pending.

Use the existing VEHICLE_WITHDRAW operation, generation and owner epoch. Add a finite initial
ALIGN/REVERSE leg, followed by screened reassessment or the existing native escape when necessary.
Never replace the effective commander to make a command work. A living local AI driver must have
a distinct eligible effective commander; otherwise retain the native escape path.

Select a short rearward terrain-checked leg from the current hull orientation. Reject water,
excessive grade, solid obstructions and a corridor that would move toward the threat. Preserve
native turret aiming and allow fire while reversing. Do not rotate the chassis with transforms,
apply scripted velocity, or send a competing forward waypoint during the reverse leg.

Issue BACK only when entering the reverse phase. Apply LEFT/RIGHT only when the hull exits a
reasonable threat-facing tolerance, and STOPTURNING when alignment returns. Every command checks
locality, operation generation, player/Zeus/specialist ownership and current crew eligibility.
Bounded lack of physical progress ends the reverse attempt and falls back once to native escape.
A short successful leg reaches cover or gains separation before reassessment; no timer alone
proves withdrawal. Smoke direction uses the recorded threat bearing, not a smoke object's location.

Cancellation must stop only matching WAIT-owned simple commands before accepting a replacement
order. Locality adoption preserves the durable escape intent and physical progress, retires inherited reverse commands, then revalidates
terrain and crew capability on the new owner. No new persistent worker is permitted; steps use the
existing shared group scheduler. The current seven-field withdrawal snapshot needs a documented
extension or a separate versioned reverse snapshot, with matching release and migration handling.

Acceptance: tracked tank and APC reverse physically with threat-facing hull, turret engagement,
blocked rear route, hill/water rejection, no-progress fallback, absent commander, casualty during
reverse, live disable, Zeus replacement and headless migration. Wheeled escape remains unchanged.
Compare matched baseline frame time; add no per-unit/per-frame loop or repeated route planning.
