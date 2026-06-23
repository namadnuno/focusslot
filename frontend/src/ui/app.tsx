import {
  CalendarCog,
  CalendarDays,
  CalendarPlus,
  Check,
  Clock,
  Edit3,
  ExternalLink,
  MoreHorizontal,
  Plus,
  RotateCcw,
  Settings,
  Trash2,
  X
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { sendNative } from "../lib/native";
import type { AppState, CalendarTask, SchedulingSettings, TaskCategory } from "../lib/types";
import { categories, durations } from "../lib/types";
import {
  datetimeLocalValue,
  formatDate,
  formatTime,
  fromDatetimeLocalInput,
  startOfLocalDayISO
} from "../lib/utils";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import { Card } from "@/components/ui/card";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { NativeSelect as Select, NativeSelectOption as Option } from "@/components/ui/native-select";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Separator } from "@/components/ui/separator";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";

const categoryStyles: Record<TaskCategory, string> = {
  CS: "border-blue-500/20 bg-blue-500/10 text-blue-700 dark:text-blue-300",
  Bugs: "border-red-500/20 bg-red-500/10 text-red-700 dark:text-red-300",
  Feature: "border-violet-500/20 bg-violet-500/10 text-violet-700 dark:text-violet-300",
  Pair: "border-amber-500/20 bg-amber-500/10 text-amber-700 dark:text-amber-300",
  Investigation: "border-teal-500/20 bg-teal-500/10 text-teal-700 dark:text-teal-300"
};

type StatusMessage = {
  text: string;
  tone: "success" | "error";
};

type EditDraft = {
  id: string;
  title: string;
  category: TaskCategory;
  startDate: string;
  durationMinutes: number;
};

type DayFilter = "today" | "tomorrow" | "custom";

export function App() {
  const [selectedDate, setSelectedDate] = useState(() => new Date());
  const [state, setState] = useState<AppState | null>(null);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [status, setStatus] = useState<StatusMessage | null>(null);
  const [isBusy, setIsBusy] = useState(false);
  const [title, setTitle] = useState("");
  const [category, setCategory] = useState<TaskCategory>("CS");
  const [durationMinutes, setDurationMinutes] = useState(15);
  const [editDraft, setEditDraft] = useState<EditDraft | null>(null);
  const [dayFilter, setDayFilter] = useState<DayFilter>("today");
  const [isCustomDateOpen, setIsCustomDateOpen] = useState(false);

  const selectedDateISO = useMemo(() => startOfLocalDayISO(selectedDate), [selectedDate]);

  useEffect(() => {
    void refresh("initialize");
  }, []);

  async function refresh(type = "loadEvents", date = selectedDateISO) {
    setIsBusy(true);
    try {
      const nextState = await sendNative<{ selectedDate: string }, AppState>(type, {
        selectedDate: date
      });
      setState(nextState);
    } catch (error) {
      setStatus({ text: error instanceof Error ? error.message : String(error), tone: "error" });
    } finally {
      setIsBusy(false);
    }
  }

  async function runMutation<TPayload>(type: string, payload: TPayload, success: string) {
    setIsBusy(true);
    try {
      const nextState = await sendNative<TPayload, AppState>(type, payload);
      setState(nextState);
      setStatus({ text: success, tone: "success" });
      return nextState;
    } catch (error) {
      setStatus({ text: error instanceof Error ? error.message : String(error), tone: "error" });
      return null;
    } finally {
      setIsBusy(false);
    }
  }

  async function addTask() {
    const trimmedTitle = title.trim();
    if (!trimmedTitle) return;

    const nextState = await runMutation(
      "addTask",
      {
        title: trimmedTitle,
        category,
        durationMinutes,
        selectedDate: selectedDateISO
      },
      "Task added"
    );

    if (nextState) {
      setTitle("");
    }
  }

  async function saveTask() {
    if (!editDraft) return;

    const trimmedTitle = editDraft.title.trim();
    if (!trimmedTitle) return;

    const startDate = fromDatetimeLocalInput(editDraft.startDate);

    const nextState = await runMutation(
      "updateTask",
      {
        eventID: editDraft.id,
        title: trimmedTitle,
        category: editDraft.category,
        startDate: startDate.toISOString(),
        durationMinutes: editDraft.durationMinutes,
        selectedDate: startOfLocalDayISO(startDate)
      },
      "Task updated"
    );

    if (nextState) {
      setSelectedDate(startDate);
      setDayFilter(filterForDate(startDate));
      setEditDraft(null);
    }
  }

  async function updateSettings(settings: SchedulingSettings) {
    await runMutation(
      "updateSettings",
      {
        settings,
        selectedDate: selectedDateISO
      },
      "Settings updated"
    );
  }

  function startEditing(task: CalendarTask) {
    setEditDraft({
      id: task.id,
      title: task.displayTitle,
      category: task.category ?? "CS",
      startDate: datetimeLocalValue(new Date(task.startDate)),
      durationMinutes: task.durationMinutes
    });
    setStatus(null);
  }

  function selectDate(nextDate: Date, nextFilter = filterForDate(nextDate)) {
    setSelectedDate(nextDate);
    setDayFilter(nextFilter);
    setEditDraft(null);
    void refresh("loadEvents", startOfLocalDayISO(nextDate));
  }

  function handleDayFilterChange(value: string) {
    const nextFilter = value as DayFilter;

    if (nextFilter === "today") {
      setIsCustomDateOpen(false);
      selectDate(new Date(), "today");
      return;
    }

    if (nextFilter === "tomorrow") {
      setIsCustomDateOpen(false);
      selectDate(addDays(new Date(), 1), "tomorrow");
      return;
    }

    setDayFilter("custom");
    setIsCustomDateOpen(true);
  }

  if (!state) {
    return (
      <Shell>
        <div className="grid h-full place-items-center text-sm text-muted-foreground">Loading FocusSlot...</div>
      </Shell>
    );
  }

  return (
    <Shell>
      <header className="space-y-3">
        <div className="flex items-center gap-3">
          <div className="grid h-10 w-10 place-items-center rounded-xl bg-primary text-primary-foreground shadow-sm">
            <CalendarPlus className="h-5 w-5" />
          </div>
          <div className="min-w-0">
            <h1 className="truncate text-xl font-semibold tracking-tight">FocusSlot</h1>
            <p className="text-xs text-muted-foreground">
              {state.tasks.length} tasks on {formatDate(selectedDate)}
            </p>
          </div>
          <Button
            className="ml-auto"
            aria-label="Settings"
            size="icon"
            variant={isSettingsOpen ? "default" : "secondary"}
            onClick={() => setIsSettingsOpen((value) => !value)}
          >
            {isSettingsOpen ? <Check className="h-4 w-4" /> : <Settings className="h-4 w-4" />}
          </Button>
        </div>

        <DayFilterControl
          value={dayFilter}
          selectedDate={selectedDate}
          isCustomDateOpen={isCustomDateOpen}
          onOpenChange={setIsCustomDateOpen}
          onValueChange={handleDayFilterChange}
          onCustomDateSelect={(date) => {
            selectDate(date, "custom");
            setIsCustomDateOpen(false);
          }}
        />
      </header>

      {state.accessState.status === "denied" ? (
        <AccessDenied message={state.accessState.message} onRetry={() => refresh("initialize")} />
      ) : isSettingsOpen ? (
        <SettingsPanel state={state} onChange={updateSettings} />
      ) : (
        <>
          <section className="min-h-0 flex-1">
            <div className="mb-3 flex items-center justify-between">
              <h2 className="text-sm font-semibold">Tasks</h2>
              {isBusy && <span className="text-xs text-muted-foreground">Syncing...</span>}
            </div>
            <TaskList
              tasks={state.tasks}
              onEdit={startEditing}
              onDone={(task) =>
                runMutation(
                  "markDone",
                  { eventID: task.id, selectedDate: selectedDateISO },
                  "Marked done"
                )
              }
              onMove={(task) =>
                runMutation(
                  "moveNext",
                  { eventID: task.id, selectedDate: selectedDateISO },
                  "Moved to next slot"
                )
              }
              onDelete={(task) =>
                runMutation(
                  "deleteTask",
                  { eventID: task.id, selectedDate: selectedDateISO },
                  "Deleted task"
                )
              }
            />
          </section>

          <Separator />

          {editDraft ? (
            <EditTaskForm
              draft={editDraft}
              onChange={setEditDraft}
              onCancel={() => setEditDraft(null)}
              onSave={saveTask}
              disabled={isBusy}
            />
          ) : (
            <NewTaskForm
              title={title}
              category={category}
              durationMinutes={durationMinutes}
              disabled={isBusy}
              onTitleChange={setTitle}
              onCategoryChange={setCategory}
              onDurationChange={setDurationMinutes}
              onSubmit={addTask}
            />
          )}
        </>
      )}

      {status && (
        <p className={status.tone === "success" ? "text-xs text-emerald-600" : "text-xs text-destructive"}>
          {status.text}
        </p>
      )}
    </Shell>
  );
}

function DayFilterControl({
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

function filterForDate(date: Date): DayFilter {
  const today = new Date();
  const tomorrow = addDays(today, 1);

  if (isSameLocalDay(date, today)) return "today";
  if (isSameLocalDay(date, tomorrow)) return "tomorrow";

  return "custom";
}

function addDays(date: Date, days: number) {
  const nextDate = new Date(date);
  nextDate.setDate(nextDate.getDate() + days);
  return nextDate;
}

function isSameLocalDay(firstDate: Date, secondDate: Date) {
  return (
    firstDate.getFullYear() === secondDate.getFullYear() &&
    firstDate.getMonth() === secondDate.getMonth() &&
    firstDate.getDate() === secondDate.getDate()
  );
}

function Shell({ children }: { children: React.ReactNode }) {
  return <main className="flex h-screen flex-col gap-4 overflow-hidden p-5">{children}</main>;
}

function AccessDenied({ message, onRetry }: { message: string; onRetry: () => void }) {
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

function TaskList({
  tasks,
  onEdit,
  onDone,
  onMove,
  onDelete
}: {
  tasks: CalendarTask[];
  onEdit: (task: CalendarTask) => void;
  onDone: (task: CalendarTask) => void;
  onMove: (task: CalendarTask) => void;
  onDelete: (task: CalendarTask) => void;
}) {
  if (tasks.length === 0) {
    return (
      <Card className="grid h-[300px] place-items-center p-6 text-center">
        <div>
          <Clock className="mx-auto h-8 w-8 text-muted-foreground" />
          <h3 className="mt-3 text-sm font-medium">No tasks</h3>
          <p className="mt-1 text-xs text-muted-foreground">No [Task] events for this day.</p>
        </div>
      </Card>
    );
  }

  return (
    <div className="h-[300px] space-y-2 overflow-y-auto pr-1">
      {tasks.map((task) => (
        <TaskItem
          key={task.id}
          task={task}
          onEdit={onEdit}
          onDone={onDone}
          onMove={onMove}
          onDelete={onDelete}
        />
      ))}
    </div>
  );
}

function TaskItem({
  task,
  onEdit,
  onDone,
  onMove,
  onDelete
}: {
  task: CalendarTask;
  onEdit: (task: CalendarTask) => void;
  onDone: (task: CalendarTask) => void;
  onMove: (task: CalendarTask) => void;
  onDelete: (task: CalendarTask) => void;
}) {
  const start = new Date(task.startDate);
  const end = new Date(task.endDate);

  return (
    <Card className="group relative p-3">
      <div className={`absolute inset-y-3 left-0 w-1 rounded-r ${task.isDone ? "bg-emerald-500" : "bg-primary"}`} />
      <div className="flex items-center gap-3 pl-2">
        <div className="min-w-0 flex-1">
          <div className="flex min-w-0 items-center gap-2">
            {task.category && <Badge className={categoryStyles[task.category]}>{task.category}</Badge>}
            <p className="truncate text-sm font-medium">{task.displayTitle}</p>
          </div>
          <p className="mt-1 text-xs text-muted-foreground">
            {formatTime(start)} - {formatTime(end)}
          </p>
        </div>
        <span className="text-xs tabular-nums text-muted-foreground">{task.durationMinutes}m</span>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button size="icon" variant="ghost" className="h-8 w-8">
              <MoreHorizontal className="h-4 w-4" />
              <span className="sr-only">Task actions</span>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-48">
            <DropdownMenuItem onSelect={() => onEdit(task)}>
              <Edit3 className="h-4 w-4" />
              Edit
            </DropdownMenuItem>
            <DropdownMenuItem disabled={task.isDone} onSelect={() => onDone(task)}>
              <Check className="h-4 w-4" />
              Mark done
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => onMove(task)}>
              <RotateCcw className="h-4 w-4" />
              Next slot
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem variant="destructive" onSelect={() => onDelete(task)}>
              <Trash2 className="h-4 w-4" />
              Delete
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </Card>
  );
}

function NewTaskForm({
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

function EditTaskForm({
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

function SettingsPanel({
  state,
  onChange
}: {
  state: AppState;
  onChange: (settings: SchedulingSettings) => void;
}) {
  const settings = state.settings;

  function patch(partial: Partial<SchedulingSettings>) {
    onChange({ ...settings, ...partial });
  }

  return (
    <Card className="flex-1 space-y-4 overflow-y-auto p-4">
      <div>
        <h2 className="text-sm font-semibold">Settings</h2>
        <p className="text-xs text-muted-foreground">Stored locally on this Mac.</p>
      </div>

      <Field label="Task calendar">
        <Select
          className="w-full"
          value={settings.calendarIdentifier ?? ""}
          onChange={(event) => patch({ calendarIdentifier: event.target.value || null })}
        >
          <Option value="">Default writable calendar</Option>
          {state.calendars.map((calendar) => (
            <Option key={calendar.id} value={calendar.id}>
              {calendar.title} ({calendar.source})
            </Option>
          ))}
        </Select>
      </Field>

      <div className="grid grid-cols-2 gap-3">
        <TimeField
          label="Workday start"
          hour={settings.workdayStartHour}
          minute={settings.workdayStartMinute}
          onChange={(hour, minute) => patch({ workdayStartHour: hour, workdayStartMinute: minute })}
        />
        <TimeField
          label="Workday end"
          hour={settings.workdayEndHour}
          minute={settings.workdayEndMinute}
          onChange={(hour, minute) => patch({ workdayEndHour: hour, workdayEndMinute: minute })}
        />
        <TimeField
          label="Lunch start"
          hour={settings.lunchStartHour}
          minute={settings.lunchStartMinute}
          onChange={(hour, minute) => patch({ lunchStartHour: hour, lunchStartMinute: minute })}
        />
        <TimeField
          label="Lunch end"
          hour={settings.lunchEndHour}
          minute={settings.lunchEndMinute}
          onChange={(hour, minute) => patch({ lunchEndHour: hour, lunchEndMinute: minute })}
        />
      </div>

      <div className="grid grid-cols-2 gap-3">
        <Field label="Buffer">
          <Input
            type="number"
            min={0}
            max={60}
            step={5}
            value={settings.bufferMinutes}
            onChange={(event) => patch({ bufferMinutes: Number(event.target.value) })}
          />
        </Field>
        <Field label="Granularity">
          <Input
            type="number"
            min={1}
            max={30}
            value={settings.slotGranularityMinutes}
            onChange={(event) => patch({ slotGranularityMinutes: Number(event.target.value) })}
          />
        </Field>
      </div>

      <label className="flex items-center justify-between rounded-lg border p-3 text-sm">
        Auto-rebalance tasks
        <input
          type="checkbox"
          checked={settings.autoRebalance}
          onChange={(event) => patch({ autoRebalance: event.target.checked })}
        />
      </label>
    </Card>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="space-y-1.5 text-sm">
      <span className="text-xs font-medium text-muted-foreground">{label}</span>
      {children}
    </label>
  );
}

function TimeField({
  label,
  hour,
  minute,
  onChange
}: {
  label: string;
  hour: number;
  minute: number;
  onChange: (hour: number, minute: number) => void;
}) {
  const value = `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;

  return (
    <Field label={label}>
      <Input
        type="time"
        step={300}
        value={value}
        onChange={(event) => {
          const [nextHour, nextMinute] = event.target.value.split(":").map(Number);
          onChange(nextHour, nextMinute);
        }}
      />
    </Field>
  );
}
