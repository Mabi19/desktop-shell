import { type Subscribable } from "astal/binding";

export class Notifier implements Subscribable<void> {
    private subscriptions = new Set<() => void>();

    notify() {
        for (const sub of this.subscriptions) {
            sub();
        }
    }

    get() {}

    subscribe(callback: () => void) {
        this.subscriptions.add(callback);
        return () => this.subscriptions.delete(callback);
    }
}
