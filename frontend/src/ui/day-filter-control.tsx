import { CalendarDays } from "lucide-react";
import type { DayFilter } from "@/lib/use-focus-slot";
import { formatDate } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";

export function DayFilterControl({
  value,
  selectedDate,
  isCustomDateOpen,
  onOpenChange,
  onValueChange,
  onCustomDateSelect
}: {
  value: DayFilter;
  selectedDate: Date;
  isCustomDateOpen: boolean;
  onOpenChange: (open: boolean) => void;
  onValueChange: (value: string) => void;
  onCustomDateSelect: (date: Date) => void;
}) {
  return (
    <div className="flex items-center gap-2">
      <Tabs value={value} onValueChange={onValueChange}>
        <TabsList className="w-[236px]">
          <TabsTrigger value="today">Today</TabsTrigger>
          <TabsTrigger value="tomorrow">Tomorrow</TabsTrigger>
          <TabsTrigger value="custom">Custom</TabsTrigger>
        </TabsList>
      </Tabs>

      {value === "custom" && (
        <Popover open={isCustomDateOpen} onOpenChange={onOpenChange}>
          <PopoverTrigger asChild>
            <Button
              className="w-[132px] justify-start text-left font-normal"
              variant="outline"
            >
              <CalendarDays className="h-4 w-4" />
              {formatDate(selectedDate)}
            </Button>
          </PopoverTrigger>
          <PopoverContent align="end" className="w-auto p-0">
            <Calendar
              mode="single"
              selected={selectedDate}
              onSelect={(date) => {
                if (date) onCustomDateSelect(date);
              }}
            />
          </PopoverContent>
        </Popover>
      )}
    </div>
  );
}
