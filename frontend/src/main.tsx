import React from "react";
import { createRoot } from "react-dom/client";
import { App } from "./ui/app";
import { ErrorBoundary } from "./ui/error-boundary";
import "./styles.css";

console.info("FocusSlot frontend module loaded");
console.info("FocusSlot createRoot type", typeof createRoot);

window.webkit?.messageHandlers?.focusSlot?.postMessage({
  type: "__frontendReady"
});

try {
  const rootElement = document.getElementById("root");

  if (!rootElement) {
    throw new Error("Missing #root element");
  }

  console.info("FocusSlot creating React root");

  createRoot(rootElement).render(
    <React.StrictMode>
      <ErrorBoundary>
        <App />
      </ErrorBoundary>
    </React.StrictMode>
  );

  console.info("FocusSlot React render scheduled");
} catch (error) {
  console.error("FocusSlot bootstrap failed", describeError(error));

  const rootElement = document.getElementById("root");
  if (rootElement) {
    rootElement.innerHTML = `
      <main style="display:grid;min-height:100vh;place-items:center;margin:0;padding:24px;font:13px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#991b1b;background:#fff;">
        <div style="max-width:320px;text-align:center;">
          <strong>FocusSlot failed to start</strong>
          <p style="color:#666;word-break:break-word;">${error instanceof Error ? error.message : String(error)}</p>
        </div>
      </main>
    `;
  }
}

function describeError(error: unknown) {
  if (error instanceof Error) {
    return {
      name: error.name,
      message: error.message,
      stack: error.stack
    };
  }

  if (error && typeof error === "object") {
    const value = error as Record<string, unknown>;
    return {
      type: Object.prototype.toString.call(error),
      name: value.name,
      message: value.message,
      stack: value.stack,
      stringValue: String(error)
    };
  }

  return {
    type: typeof error,
    stringValue: String(error)
  };
}
