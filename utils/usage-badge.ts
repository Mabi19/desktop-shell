// numbered [0, n - 1]
// 0 = 0%, n - 1 = 100%
const STEPS = 6;

export function getUsageBadgeClass(usagePercent: number) {
    // clamp
    usagePercent = Math.max(Math.min(usagePercent, 1), 0);
    // change curve to emphasize changes at small amounts
    usagePercent = Math.pow(usagePercent, 0.75);

    return `step-${Math.min(STEPS - 1, Math.floor(usagePercent * STEPS))}`;
}

// This function isn't useful right now since we're doing steps in GTK 4.
// But it might still be useful later.
export function mixUsageBadgeColor(usagePercent: number) {
    // clamp
    usagePercent = Math.max(Math.min(usagePercent, 1), 0);
    // change curve to emphasize changes at small amounts
    usagePercent = Math.pow(usagePercent, 0.75);

    const min = [192, 99, 201];
    const max = [134, 67, 181];
    const mixed = [0, 0, 0];
    for (let i = 0; i < 3; i++) {
        mixed[i] = Math.round(min[i] * (1 - usagePercent) + max[i] * usagePercent);
    }

    return `rgb(${mixed[0]}, ${mixed[1]}, ${mixed[2]})`;
}
