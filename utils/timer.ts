import { interval } from "astal";
import type AstalIO from "gi://AstalIO";
import GLib from "gi://GLib";
import { Notifier } from "./notifier";

export class Timer extends Notifier {
    isPaused: boolean;
    timeout: number;
    timeLeft: number;
    private lastTickTime: number;
    private interval: AstalIO.Time | null;

    constructor(timeout: number) {
        super();
        this.timeout = timeout;
        this.timeLeft = timeout;
        this.isPaused = false;
        this.lastTickTime = GLib.get_monotonic_time();

        this.interval = interval(20, () => this.tick());
    }

    protected unsubscribe(callback: () => void): void {
        super.unsubscribe(callback);
        if (this.subscriptions.size == 0 && this.isPaused && this.interval != null) {
            console.warn("Timer was disconnected while paused");
            // clean it up anyway
            this.isPaused = false;
        }
    }

    tick() {
        const now = GLib.get_monotonic_time();
        if (this.isPaused) {
            this.lastTickTime = now;
            return;
        }
        const delta = (now - this.lastTickTime) / 1000;
        this.timeLeft -= delta;

        if (this.timeLeft <= 0) {
            this.timeLeft = 0;
            this.cancel();
        }

        this.notify();
        this.lastTickTime = now;
    }

    cancel() {
        this.interval?.cancel();
        this.interval = null;
    }
}
