import React from "react";
import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";

type ErrorBoundaryState = {
  error: Error | null;
};

export class ErrorBoundary extends React.Component<React.PropsWithChildren, ErrorBoundaryState> {
  state: ErrorBoundaryState = {
    error: null
  };

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    console.error("React render error", error, info.componentStack);
  }

  render() {
    if (!this.state.error) {
      return this.props.children;
    }

    return (
      <main className="grid h-screen place-items-center bg-background p-6 text-foreground">
        <Card className="max-w-sm gap-4 p-5 text-center">
          <div className="mx-auto grid h-12 w-12 place-items-center rounded-full bg-destructive/10 text-destructive">
            <AlertTriangle className="h-6 w-6" />
          </div>
          <div>
            <h1 className="font-semibold">FocusSlot UI crashed</h1>
            <p className="mt-2 break-words text-sm text-muted-foreground">
              {this.state.error.message}
            </p>
          </div>
          <Button onClick={() => window.location.reload()}>Reload</Button>
        </Card>
      </main>
    );
  }
}
