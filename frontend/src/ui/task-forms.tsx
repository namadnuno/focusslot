import { useState } from "react";
import { Plus } from "lucide-react";
import type { CalendarTask, TaskCategory } from "@/lib/types";
import { durations } from "@/lib/types";
import type { EditDraft, MoveOption } from "@/lib/use-focus-slot";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { NativeSelect as Select, NativeSelectOption as Option } from "@/components/ui/native-select";
import { Switch } from "@/components/ui/switch";
import { CategoryPicker } from "./category-picker";

export function NewTaskForm({
  title,
  category,
  durationMinutes,
  customTimeEnabled,
  customStartDate,
  disabled,
  onTitleChange,
  onCategoryChange,
  onDurationChange,
  onCustomTimeToggle,
  onCustomStartChange,
  onSubmit
}: {
  title: string;
  category: TaskCategory;
  durationMinutes: number;
  customTimeEnabled: boolean;
  customStartDate: string;
  disabled: boolean;
  onTitleChange: (value: string) => void;
  onCategoryChange: (value: TaskCategory) => void;
  onDurationChange: (value: number) => void;
  onCustomTimeToggle: (enabled: boolean) => void;
  onCustomStartChange: (value: string) => void;
  onSubmit: () => void;
}) {
  return (
    <div className="space-y-4 px-4 pb-4">
      <Input
        autoFocus
        placeholder="What are you working on?"
        value={title}
        onChange={(event) => onTitleChange(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === "Enter") onSubmit();
        }}
      />

      <div className="space-y-1.5">
        <Label className="text-xs font-medium text-muted-foreground">Category</Label>
        <CategoryPicker value={category} onChange={onCategoryChange} />
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="new-task-duration" className="text-xs font-medium text-muted-foreground">
          Duration
        </Label>
        <Select
          id="new-task-duration"
          className="w-full"
          value={durationMinutes}
          onChange={(event) => onDurationChange(Number(event.target.value))}
        >
          {durations.map((value) => (
            <Option key={value} value={value}>
              {value}m
            </Option>
          ))}
        </Select>
      </div>

      <div className="space-y-2.5 rounded-lg border p-3">
        <div className="flex items-center justify-between gap-3">
          <div className="space-y-0.5">
            <Label htmlFor="custom-time" className="text-sm font-normal">
              Custom time
            </Label>
            <p className="text-xs text-muted-foreground">
              {customTimeEnabled ? "Pick when this task starts." : "Auto-scheduled to the next free slot."}
            </p>
          </div>
          <Switch id="custom-time" checked={customTimeEnabled} onCheckedChange={onCustomTimeToggle} />
        </div>
        {customTimeEnabled && (
          <Input
            type="datetime-local"
            value={customStartDate}
            onChange={(event) => onCustomStartChange(event.target.value)}
          />
        )}
      </div>

      <Button className="w-full" disabled={disabled || !title.trim()} onClick={onSubmit}>
        <Plus className="h-4 w-4" />
        Add Task
      </Button>
    </div>
  );
}

const MOVE_OPTIONS: { label: string; value: string }[] = [
  { label: "15 minutes", value: "15" },
  { label: "30 minutes", value: "30" },
  { label: "1 hour", value: "60" },
  { label: "2 hours", value: "120" },
  { label: "3 hours", value: "180" },
  { label: "Next day", value: "nextDay" }
];

export function MoveTaskForm({
  task,
  disabled,
  onMove,
  onCancel
}: {
  task: CalendarTask;
  disabled: boolean;
  onMove: (option: MoveOption) => void;
  onCancel: () => void;
}) {
  const [value, setValue] = useState("30");

  return (
    <div className="space-y-4 px-4 pb-4">
      <p className="text-sm text-muted-foreground">
        Move <span className="font-medium text-foreground">{task.displayTitle}</span> forward by:
      </p>

      <Select className="w-full" value={value} onChange={(event) => setValue(event.target.value)}>
        {MOVE_OPTIONS.map((option) => (
          <Option key={option.value} value={option.value}>
            {option.label}
          </Option>
        ))}
      </Select>

      <div className="flex gap-2">
        <Button className="flex-1" variant="outline" onClick={onCancel}>
          Cancel
        </Button>
        <Button
          className="flex-1"
          disabled={disabled}
          onClick={() => onMove(value === "nextDay" ? "nextDay" : (Number(value) as MoveOption))}
        >
          Move
        </Button>
      </div>
    </div>
  );
}

export function EditTaskForm({
  draft,
  disabled,
  onChange,
  onCancel,
  onSave
}: {
  draft: EditDraft;
  disabled: boolean;
  onChange: (draft: EditDraft) => void;
  onCancel: () => void;
  onSave: () => void;
}) {
  return (
    <div className="space-y-4 px-4 pb-4">
      <Input
        autoFocus
        value={draft.title}
        onChange={(event) => onChange({ ...draft, title: event.target.value })}
        onKeyDown={(event) => {
          if (event.key === "Enter") onSave();
        }}
      />

      <div className="space-y-1.5">
        <Label className="text-xs font-medium text-muted-foreground">Category</Label>
        <CategoryPicker
          value={draft.category}
          onChange={(category) => onChange({ ...draft, category })}
        />
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <Label htmlFor="edit-task-duration" className="text-xs font-medium text-muted-foreground">
            Duration
          </Label>
          <Select
            id="edit-task-duration"
            className="w-full"
            value={draft.durationMinutes}
            onChange={(event) => onChange({ ...draft, durationMinutes: Number(event.target.value) })}
          >
            {durations.map((value) => (
              <Option key={value} value={value}>
                {value}m
              </Option>
            ))}
          </Select>
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="edit-task-start" className="text-xs font-medium text-muted-foreground">
            Start
          </Label>
          <Input
            id="edit-task-start"
            type="datetime-local"
            value={draft.startDate}
            onChange={(event) => onChange({ ...draft, startDate: event.target.value })}
          />
        </div>
      </div>

      <div className="flex gap-2">
        <Button className="flex-1" variant="outline" onClick={onCancel}>
          Cancel
        </Button>
        <Button className="flex-1" disabled={disabled || !draft.title.trim()} onClick={onSave}>
          Save
        </Button>
      </div>
    </div>
  );
}
