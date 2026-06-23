import { Edit3, Plus, X } from "lucide-react";
import type { TaskCategory } from "@/lib/types";
import { categories, durations } from "@/lib/types";
import type { EditDraft } from "@/lib/use-focus-slot";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { NativeSelect as Select, NativeSelectOption as Option } from "@/components/ui/native-select";

export function NewTaskForm({
  title,
  category,
  durationMinutes,
  disabled,
  onTitleChange,
  onCategoryChange,
  onDurationChange,
  onSubmit
}: {
  title: string;
  category: TaskCategory;
  durationMinutes: number;
  disabled: boolean;
  onTitleChange: (value: string) => void;
  onCategoryChange: (value: TaskCategory) => void;
  onDurationChange: (value: number) => void;
  onSubmit: () => void;
}) {
  return (
    <Card className="space-y-3 p-4">
      <div className="flex items-center gap-2">
        <Plus className="h-4 w-4 text-muted-foreground" />
        <h2 className="text-sm font-semibold">New task</h2>
      </div>
      <Input
        placeholder="Task title"
        value={title}
        onChange={(event) => onTitleChange(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === "Enter") onSubmit();
        }}
      />
      <div className="grid grid-cols-[1fr_116px] gap-2">
        <Select value={category} onChange={(event) => onCategoryChange(event.target.value as TaskCategory)}>
          {categories.map((value) => (
            <Option key={value} value={value}>
              {value}
            </Option>
          ))}
        </Select>
        <Select value={durationMinutes} onChange={(event) => onDurationChange(Number(event.target.value))}>
          {durations.map((value) => (
            <Option key={value} value={value}>
              {value}m
            </Option>
          ))}
        </Select>
      </div>
      <Button className="w-full" disabled={disabled || !title.trim()} onClick={onSubmit}>
        <Plus className="h-4 w-4" />
        Add Task
      </Button>
    </Card>
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
    <Card className="space-y-3 p-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Edit3 className="h-4 w-4 text-muted-foreground" />
          <h2 className="text-sm font-semibold">Edit task</h2>
        </div>
        <Button size="icon" variant="ghost" onClick={onCancel}>
          <X className="h-4 w-4" />
        </Button>
      </div>
      <Input
        value={draft.title}
        onChange={(event) => onChange({ ...draft, title: event.target.value })}
        onKeyDown={(event) => {
          if (event.key === "Enter") onSave();
        }}
      />
      <div className="grid grid-cols-[1fr_116px] gap-2">
        <Select
          value={draft.category}
          onChange={(event) => onChange({ ...draft, category: event.target.value as TaskCategory })}
        >
          {categories.map((value) => (
            <Option key={value} value={value}>
              {value}
            </Option>
          ))}
        </Select>
        <Select
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
      <Input
        type="datetime-local"
        value={draft.startDate}
        onChange={(event) => onChange({ ...draft, startDate: event.target.value })}
      />
      <div className="flex gap-2">
        <Button className="flex-1" variant="outline" onClick={onCancel}>
          Cancel
        </Button>
        <Button className="flex-1" disabled={disabled || !draft.title.trim()} onClick={onSave}>
          Save
        </Button>
      </div>
    </Card>
  );
}
