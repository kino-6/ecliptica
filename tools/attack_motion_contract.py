from __future__ import annotations

TIMING_BY_FRAME = [0.00, 0.05, 0.12, 0.15, 0.68, 1.00, 0.88, 0.72]

AXE_POSE_SETS = [
    [
        (105.0, 178.0, -132.0, 0.97),
        (101.0, 151.0, -156.0, 0.99),
        (98.0, 136.0, -178.0, 1.00),
        (100.0, 134.0, -180.0, 1.00),
        (84.0, 153.0, -82.0, 1.02),
        (112.0, 184.0, -12.0, 1.03),
        (136.0, 202.0, 38.0, 1.01),
        (118.0, 194.0, 20.0, 0.98),
    ],
    [
        (108.0, 174.0, -142.0, 0.97),
        (104.0, 140.0, -170.0, 1.00),
        (100.0, 122.0, -190.0, 1.01),
        (102.0, 121.0, -193.0, 1.01),
        (90.0, 146.0, -98.0, 1.03),
        (120.0, 176.0, -20.0, 1.04),
        (141.0, 198.0, 42.0, 1.01),
        (122.0, 190.0, 22.0, 0.98),
    ],
    [
        (110.0, 172.0, -150.0, 0.98),
        (106.0, 135.0, -182.0, 1.00),
        (102.0, 116.0, -204.0, 1.02),
        (104.0, 115.0, -207.0, 1.02),
        (94.0, 150.0, -104.0, 1.04),
        (127.0, 188.0, -8.0, 1.05),
        (148.0, 211.0, 48.0, 1.02),
        (126.0, 197.0, 24.0, 0.99),
    ],
]

STEP_BIASES = [
    {"lean": 14.0, "shear": 9.0, "lift": -1.0},
    {"lean": 18.0, "shear": 12.0, "lift": -5.0},
    {"lean": 22.0, "shear": 14.0, "lift": -8.0},
]


def _build_pose(step: int, frame: int) -> dict:
    timing = TIMING_BY_FRAME[frame]
    windup = 1.0 if frame in [1, 2, 3] else max(0.0, 1.0 - timing)
    impact = 1.0 if frame == 5 else 0.0
    follow = 1.0 if frame >= 6 else 0.0
    follow_drive = 1.0 if frame == 6 else 0.45 if frame == 7 else 0.0
    held_weight = 1.0 if frame == 3 else 0.0
    bias = STEP_BIASES[step]
    lean = -9.0 * windup + bias["lean"] * timing + impact * 9.0 + follow_drive * 11.0 - held_weight * 2.0
    shear = -6.0 * windup + (timing - 0.32) * bias["shear"] + impact * 5.0 + follow_drive * 3.0
    upper_lift = bias["lift"] * (windup * 0.8 + impact * 0.35) - held_weight * 1.5 + follow_drive * 2.0
    axe_x, axe_y, axe_angle, axe_scale = AXE_POSE_SETS[step][frame]
    shoulder_x = 97 + step * 3 + impact * 7 + follow_drive * 9
    shoulder_y = 139 - step * 2 + impact * 3 + follow_drive * 6
    elbow_x = 109 + step * 4 + impact * 10 + follow_drive * 16
    elbow_y = 153 + step * 2 + impact * 6 + follow_drive * 13
    hand_x = 125 + step * 5 + impact * 8 + follow_drive * 22
    hand_y = 168 + step * 4 + impact * 8 + follow_drive * 18
    offhand_x = hand_x - 15 - impact * 4 - follow_drive * 3
    offhand_y = hand_y - 9 + impact * 2 - follow_drive * 1
    return {
        "kinetic_chain": "feet_to_hips_to_shoulder_to_elbow_to_hand_to_axe_head",
        "timing": timing,
        "windup": windup,
        "impact": impact,
        "follow": follow,
        "body_shift": lean,
        "body_shear": shear,
        "body_lift": upper_lift,
        "cloth_progress": min(1.0, 0.34 + timing * 0.72),
        "shoulder": (shoulder_x, shoulder_y),
        "elbow": (elbow_x, elbow_y),
        "hand": (hand_x, hand_y),
        "offhand": (offhand_x, offhand_y),
        "axe": (axe_x, axe_y, axe_angle, axe_scale),
    }


ATTACK_MOTION_POSES = [[_build_pose(step, frame) for frame in range(8)] for step in range(3)]
