import { CalendarDays } from "lucide-react";
import type { DayFilter } from "@/lib/use-focus-slot";
import { formatDate } from "@/lib/utils";
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
    <Tabs value={value} onValueChange={onValueChange}>
      <TabsList>
        <TabsTrigger value="today">Today</TabsTrigger>
        <TabsTrigger value="tomorrow">Tomorrow</TabsTrigger>
        <Popover open={isCustomDateOpen} onOpenChange={onOpenChange}>
          <PopoverTrigger asChild>
            <TabsTrigger value="custom" className="gap-1.5">
              <CalendarDays className="h-4 w-4" />
              {value === "custom" ? formatDate(selectedDate) : "Custom"}
            </TabsTrigger>
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
      </TabsList>
    </Tabs>
  );
}
