# Triage Summary — T-1005: Teams Audio Dead on Three Machines in Same Meeting Room

## Summary
Teams audio is not working on three machines located in the same meeting room.

## Impact
- **Who:** Users of the affected meeting room (names/IDs — to-verify); whether the issue is room-specific or user-specific — to-verify.
- **How many affected:** 3 machines reported; number of distinct users/meetings impacted — to-verify.
- **Business urgency:** to-verify — no role/criticality stated; loss of audio in a shared meeting room can block scheduled meetings, so urgency should be confirmed with the user/manager, especially if meetings are imminent.

## Known Facts
- Three separate machines in the same meeting room are affected.
- The issue is with Teams audio specifically ("dead" — no further detail on input/output/both).
- Ticket reference: T-1005.

## Missing Information to Gather
- Reporting user's name, ID, and contact details (to-verify).
- Meeting room name/location and room booking/AV system in use (to-verify).
- Whether "audio dead" means no sound output, no microphone input, or both, on each machine (to-verify).
- Whether the three machines are room-dedicated devices (e.g. Teams Room system) or personal laptops brought into the room (to-verify).
- Whether audio works outside of Teams (e.g. other apps, system sound test) on the same machines (to-verify).
- Whether audio works via Teams on these machines outside the meeting room (to-verify).
- Whether this is a wired, Bluetooth, or USB audio peripheral setup in the room (to-verify).
- When the issue started, and whether it followed any change (room AV equipment swap, driver/firmware update, Teams update) (to-verify).
- Whether other meeting rooms are experiencing the same issue (to-verify).
- Whether a reboot/reconnect of the room's audio peripherals has been tried, and the result (to-verify).

## Likely Category
Collaboration/Teams — audio hardware or room AV configuration issue, possibly room-specific rather than user-specific given three machines affected in one location. Category to confirm once more detail is gathered.

## Suggested First Diagnostic Step
Check whether the room's audio issue is tied to a shared peripheral or room AV system (e.g. a conference speakerphone/hub) rather than the individual machines, by testing system-level audio (non-Teams) on one of the three machines and checking if a different room-independent device (e.g. a laptop with its own headset) has working Teams audio in the same room.
