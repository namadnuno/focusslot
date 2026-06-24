import { useEffect, useState } from "react";
import { Check, Copy, Loader2, RefreshCw, Sparkles } from "lucide-react";
import type { DailyReport } from "@/lib/use-focus-slot";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle
} from "@/components/ui/sheet";
import { Textarea } from "@/components/ui/textarea";

function formatCost(usd: number): string {
  if (usd === 0) return "$0";
  if (usd < 0.01) return `$${usd.toFixed(4)}`;
  return `$${usd.toFixed(2)}`;
}

export function DailySheet({
  report,
  isGenerating,
  onClose,
  onRegenerate,
  title = "Daily update",
  loadingLabel = "Generating your daily…"
}: {
  report: DailyReport | null;
  isGenerating: boolean;
  onClose: () => void;
  onRegenerate: () => void;
  title?: string;
  loadingLabel?: string;
}) {
  const [copied, setCopied] = useState(false);

  // Reset the copied state whenever a fresh draft arrives.
  useEffect(() => {
    setCopied(false);
  }, [report]);

  async function copy() {
    if (!report) return;
    await navigator.clipboard.writeText(report.text);
    setCopied(true);
  }

  const open = report !== null || isGenerating;
  const showLoading = isGenerating && !report;

  return (
    <Sheet open={open} onOpenChange={(value) => !value && !isGenerating && onClose()}>
      <SheetContent side="bottom" className="max-h-[92%] gap-0 overflow-y-auto rounded-t-2xl">
        <SheetHeader>
          <SheetTitle className="flex items-center gap-2.5">
            <span className="grid h-7 w-7 place-items-center rounded-lg bg-primary/10 text-primary">
              <Sparkles className="h-4 w-4" />
            </span>
            {title}
          </SheetTitle>
          <SheetDescription className="sr-only">
            AI-generated standup update from your tasks.
          </SheetDescription>
        </SheetHeader>

        <div className="space-y-3 px-4 pb-4">
          {showLoading ? (
            <div className="grid min-h-64 place-items-center rounded-md border border-dashed">
              <div className="flex flex-col items-center gap-3 text-muted-foreground">
                <Loader2 className="h-6 w-6 animate-spin text-primary" />
                <p className="text-sm">{loadingLabel}</p>
              </div>
            </div>
          ) : (
            <Textarea
              className="min-h-64 font-mono text-xs leading-relaxed"
              value={report?.text ?? ""}
              readOnly
            />
          )}

          {report && !isGenerating && (
            <p className="flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-muted-foreground">
              <span className="tabular-nums">
                {report.promptTokens.toLocaleString()} in · {report.completionTokens.toLocaleString()} out
              </span>
              {report.costUSD !== null ? (
                <span className="rounded-full bg-muted px-2 py-0.5 font-medium tabular-nums">
                  ~{formatCost(report.costUSD)} est.
                </span>
              ) : (
                <span className="text-muted-foreground/70">cost unknown for {report.model}</span>
              )}
            </p>
          )}

          <div className="flex gap-2">
            <Button className="flex-1" variant="outline" disabled={isGenerating} onClick={onRegenerate}>
              <RefreshCw className={`h-4 w-4 ${isGenerating ? "animate-spin" : ""}`} />
              {isGenerating ? "Generating…" : "Regenerate"}
            </Button>
            <Button className="flex-1" disabled={!report || isGenerating} onClick={copy}>
              {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
              {copied ? "Copied" : "Copy"}
            </Button>
          </div>
        </div>
      </SheetContent>
    </Sheet>
  );
}
