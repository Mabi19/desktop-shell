import { interval } from "astal";
import type AstalIO from "gi://AstalIO";
import GLib from "gi://GLib";
import { Notifier } from "./notifier";

export class Timer extends Notifier {
    private _pauseCount: number;
    public get pauseCount(): number {
        return this._pauseCount;
    }
    public set pauseCount(value: number) {
        if (value < 0) {
            console.warn("Tried to set negative pauses");
            value = 0;
        }
        this._pauseCount = value;
    }
    timeout: number;
    timeLeft: number;
    private lastTickTime: number;
    private interval: AstalIO.Time | null;

    constructor(timeout: number) {
        super();
        this.timeout = timeout;
        this.timeLeft = timeout;
        this._pauseCount = 0;
        this.lastTickTime = GLib.get_monotonic_time();

        this.interval = interval(20, () => this.tick());
    }

    protected unsubscribe(callback: () => void): void {
        super.unsubscribe(callback);
        if (this.subscriptions.size == 0 && this.pauseCount > 0 && this.interval != null) {
            console.warn("Timer was disconnected with active pauses");
            // clean it up anyway
            this.pauseCount = 0;
        }
    }

    tick() {
        const now = GLib.get_monotonic_time();
        if (this.pauseCount > 0) {
            // timer is paused
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
