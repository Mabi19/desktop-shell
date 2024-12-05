import { type Subscribable } from "astal/binding";

export class Notifier<T = void> implements Subscribable<T> {
    protected subscriptions = new Set<(value: T) => void>();
    protected lastValue: T;

    constructor(value: T) {
        this.lastValue = value;
    }

    notify(value: T) {
        for (const sub of this.subscriptions) {
            sub(value);
        }
    }

    get() {
        return this.lastValue;
    }

    protected unsubscribe(callback: (value: T) => void) {
        this.subscriptions.delete(callback);
    }

    subscribe(callback: (value: T) => void) {
        this.subscriptions.add(callback);
        return () => this.unsubscribe(callback);
    }
}
