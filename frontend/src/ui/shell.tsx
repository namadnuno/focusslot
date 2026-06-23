import { CalendarCog, ExternalLink, RotateCcw } from "lucide-react";
import { sendNative } from "@/lib/native";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";

export function Shell({ children }: { children: React.ReactNode }) {
  return <main className="flex h-screen flex-col gap-4 overflow-hidden p-5">{children}</main>;
}

export function AccessDenied({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <Card className="grid flex-1 place-items-center p-6 text-center">
      <div className="max-w-[300px] space-y-4">
        <div className="mx-auto grid h-12 w-12 place-items-center rounded-full bg-muted">
          <CalendarCog className="h-6 w-6 text-muted-foreground" />
        </div>
        <div>
          <h2 className="font-semibold">Calendar Access Needed</h2>
          <p className="mt-1 text-sm text-muted-foreground">{message}</p>
        </div>
        <div className="flex justify-center gap-2">
          <Button variant="outline" onClick={onRetry}>
            <RotateCcw className="h-4 w-4" />
            Try Again
          </Button>
          <Button onClick={() => sendNative("openCalendarSettings")}>
            <ExternalLink className="h-4 w-4" />
            Open Settings
          </Button>
        </div>
      </div>
    </Card>
  );
}
