export function mixUsageBadgeColor(usagePercent: number) {
    usagePercent = Math.pow(usagePercent, 0.75);

    const min = [192, 99, 201];
    const max = [134, 67, 181];
    const mixed = [0, 0, 0];
    for (let i = 0; i < 3; i++) {
        mixed[i] = Math.round(min[i] * (1 - usagePercent) + max[i] * usagePercent);
    }

    return `rgb(${mixed[0]}, ${mixed[1]}, ${mixed[2]})`;
}
