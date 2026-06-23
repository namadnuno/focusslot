import type { NativeRequest, NativeResponse } from "./types";

type PendingRequest = {
  resolve: (response: NativeResponse) => void;
  reject: (error: Error) => void;
};

declare global {
  interface Window {
    webkit?: {
      messageHandlers?: {
        focusSlot?: {
          postMessage: (request: NativeRequest | { type: "__frontendReady" | "__log"; [key: string]: unknown }) => void;
        };
      };
    };
    FocusSlotNative?: {
      receive: (response: NativeResponse) => void;
    };
  }
}

const pending = new Map<string, PendingRequest>();

window.FocusSlotNative = {
  receive(response) {
    const request = pending.get(response.id);
    if (!request) return;

    pending.delete(response.id);

    if (response.ok) {
      request.resolve(response);
    } else {
      request.reject(new Error(response.error ?? "Native command failed"));
    }
  }
};

export function sendNative<TPayload = unknown, TResult = unknown>(
  type: string,
  payload?: TPayload
): Promise<TResult> {
  const bridge = window.webkit?.messageHandlers?.focusSlot;

  if (!bridge) {
    return Promise.reject(new Error("FocusSlot native bridge is unavailable."));
  }

  const id = crypto.randomUUID();
  const request: NativeRequest<TPayload> = { id, type, payload };

  return new Promise((resolve, reject) => {
    pending.set(id, {
      resolve: (response) => resolve(response.result as TResult),
      reject
    });
    bridge.postMessage(request);
  });
}
