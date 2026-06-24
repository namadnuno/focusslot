import { useEffect, useState } from "react";
import { Check, Copy, RefreshCw, Sparkles } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle
} from "@/components/ui/sheet";
import { Textarea } from "@/components/ui/textarea";

export function DailySheet({
  text,
  isGenerating,
  onClose,
  onRegenerate
}: {
  text: string | null;
  isGenerating: boolean;
  onClose: () => void;
  onRegenerate: () => void;
}) {
  const [copied, setCopied] = useState(false);

  // Reset the copied state whenever a fresh draft arrives.
  useEffect(() => {
    setCopied(false);
  }, [text]);

  async function copy() {
    if (!text) return;
    await navigator.clipboard.writeText(text);
    setCopied(true);
  }

  return (
    <Sheet open={text !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent side="bottom" className="max-h-[92%] gap-0 overflow-y-auto rounded-t-2xl">
        <SheetHeader>
          <SheetTitle className="flex items-center gap-2.5">
            <span className="grid h-7 w-7 place-items-center rounded-lg bg-primary/10 text-primary">
              <Sparkles className="h-4 w-4" />
            </span>
            Daily update
          </SheetTitle>
          <SheetDescription className="sr-only">
            AI-generated standup update from your tasks.
          </SheetDescription>
        </SheetHeader>

        <div className="space-y-3 px-4 pb-4">
          <Textarea
            className="min-h-64 font-mono text-xs leading-relaxed"
            value={text ?? ""}
            readOnly
          />
          <div className="flex gap-2">
            <Button
              className="flex-1"
              variant="outline"
              disabled={isGenerating}
              onClick={onRegenerate}
            >
              <RefreshCw className={`h-4 w-4 ${isGenerating ? "animate-spin" : ""}`} />
              {isGenerating ? "Generating…" : "Regenerate"}
            </Button>
            <Button className="flex-1" onClick={copy}>
              {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
              {copied ? "Copied" : "Copy"}
            </Button>
          </div>
        </div>
      </SheetContent>
    </Sheet>
  );
}
