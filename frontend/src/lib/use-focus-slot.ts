import { useEffect, useMemo, useState } from "react";
import { sendNative } from "./native";
import type { AppState, CalendarTask, SchedulingSettings, TaskCategory } from "./types";
import {
  addDays,
  datetimeLocalValue,
  fromDatetimeLocalInput,
  isSameLocalDay,
  startOfLocalDayISO
} from "./utils";

function defaultCustomStart() {
  const next = new Date();
  next.setMinutes(next.getMinutes() + 30, 0, 0);
  return datetimeLocalValue(next);
}

export type StatusMessage = {
  text: string;
  tone: "success" | "error";
};

export type EditDraft = {
  id: string;
  title: string;
  category: TaskCategory;
  startDate: string;
  durationMinutes: number;
};

export type DayFilter = "today" | "tomorrow" | "custom";

export type TaskFilter = "active" | "done";

/** How far to shift a task: minutes forward, or to the next day. */
export type MoveOption = 15 | 30 | 60 | 120 | 180 | "nextDay";

export function filterForDate(date: Date): DayFilter {
  const today = new Date();
  const tomorrow = addDays(today, 1);

  if (isSameLocalDay(date, today)) return "today";
  if (isSameLocalDay(date, tomorrow)) return "tomorrow";

  return "custom";
}

export function useFocusSlot() {
  const [selectedDate, setSelectedDate] = useState(() => new Date());
  const [state, setState] = useState<AppState | null>(null);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [status, setStatus] = useState<StatusMessage | null>(null);
  const [isBusy, setIsBusy] = useState(false);
  const [title, setTitle] = useState("");
  const [category, setCategory] = useState<TaskCategory>("CS");
  const [durationMinutes, setDurationMinutes] = useState(15);
  const [customTimeEnabled, setCustomTimeEnabled] = useState(false);
  const [customStartDate, setCustomStartDate] = useState(defaultCustomStart);
  const [editDraft, setEditDraft] = useState<EditDraft | null>(null);
  const [movingTask, setMovingTask] = useState<CalendarTask | null>(null);
  const [isNewTaskOpen, setIsNewTaskOpen] = useState(false);
  const [dayFilter, setDayFilter] = useState<DayFilter>("today");
  const [taskFilter, setTaskFilter] = useState<TaskFilter>("active");
  const [isCustomDateOpen, setIsCustomDateOpen] = useState(false);

  const selectedDateISO = useMemo(() => startOfLocalDayISO(selectedDate), [selectedDate]);

  const visibleTasks = useMemo(
    () => (state?.tasks ?? []).filter((task) => (taskFilter === "done" ? task.isDone : !task.isDone)),
    [state?.tasks, taskFilter]
  );

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

    const customStart = customTimeEnabled ? fromDatetimeLocalInput(customStartDate) : null;
    const targetDateISO = customStart ? startOfLocalDayISO(customStart) : selectedDateISO;

    const nextState = await runMutation(
      "addTask",
      {
        title: trimmedTitle,
        category,
        durationMinutes,
        selectedDate: targetDateISO,
        ...(customStart ? { startDate: customStart.toISOString() } : {})
      },
      "Task added"
    );

    if (nextState) {
      setTitle("");
      setIsNewTaskOpen(false);
      setCustomTimeEnabled(false);
      setCustomStartDate(defaultCustomStart());
      if (customStart) {
        setSelectedDate(customStart);
        setDayFilter(filterForDate(customStart));
      }
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

  async function moveTask(task: CalendarTask, option: MoveOption) {
    const nextDay = option === "nextDay";
    const offsetMinutes = nextDay ? 0 : option;
    const currentStart = new Date(task.startDate);
    const newStart = nextDay
      ? addDays(currentStart, 1)
      : new Date(currentStart.getTime() + offsetMinutes * 60_000);

    const nextState = await runMutation(
      "moveTask",
      {
        eventID: task.id,
        offsetMinutes,
        nextDay,
        selectedDate: startOfLocalDayISO(newStart)
      },
      "Task moved"
    );

    if (nextState) {
      setSelectedDate(newStart);
      setDayFilter(filterForDate(newStart));
      setMovingTask(null);
    }
  }

  async function applyReminderToExisting() {
    await runMutation(
      "applyReminderToExisting",
      { selectedDate: selectedDateISO },
      "Reminder applied to upcoming tasks"
    );
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

  return {
    selectedDate,
    selectedDateISO,
    state,
    isSettingsOpen,
    setIsSettingsOpen,
    status,
    isBusy,
    title,
    setTitle,
    category,
    setCategory,
    durationMinutes,
    setDurationMinutes,
    customTimeEnabled,
    setCustomTimeEnabled,
    customStartDate,
    setCustomStartDate,
    editDraft,
    setEditDraft,
    movingTask,
    setMovingTask,
    moveTask,
    isNewTaskOpen,
    setIsNewTaskOpen,
    dayFilter,
    taskFilter,
    setTaskFilter,
    visibleTasks,
    isCustomDateOpen,
    setIsCustomDateOpen,
    refresh,
    runMutation,
    addTask,
    saveTask,
    applyReminderToExisting,
    updateSettings,
    startEditing,
    selectDate
,
    handleDayFilterChange
  };
}
