# One evidence-led follow-up

Parent inspected artifact 15014991701: the TV2 country sheet loaded, but Safari's native “View Bookmarks, Share Menu, and Open Tabs” tip covered it. Its close x was at approximately (675,826) in the 750×1334 screenshot.

The test now recognizes that tip from the current screenshot using built-in Vision. It first queries a hittable native Close/Dismiss button in the reviewed region. If unavailable, it permits exactly one reviewed close-coordinate tap only at the same screenshot dimensions. It independently checks that the tip text disappears, then requeries +1.

If the +1 web button is not exposed, only a uniquely OCR-recognized “Shared calling-code namespace” row inside the visible country sheet may be tapped. The next screenshot must independently show +1 and ENTER LIST NUMBER without the country sheet. Missing keypad button semantics then fail explicitly; no guessed keypad coordinates. No extra retry is automatic. Existing deadlines and screenshot privacy restrictions remain.

This is Simulator UI automation, not physical-device evidence. Vision is an Apple framework on the existing runner, not a new service or paid dependency.
