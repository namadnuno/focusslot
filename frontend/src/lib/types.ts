export type TaskCategory = "CS" | "Bugs" | "Feature" | "Pair" | "Investigation";

export type CalendarAccessState =
  | { status: "unknown" | "requesting" | "granted" }
  | { status: "denied"; message: string };

export type CalendarOption = {
  id: string;
  title: string;
  source: string;
  allowsContentModifications: boolean;
};

export type SchedulingSettings = {
  workdayStartHour: number;
  workdayStartMinute: number;
  workdayEndHour: number;
  workdayEndMinute: number;
  lunchStartHour: number;
  lunchStartMinute: number;
  lunchEndHour: number;
  lunchEndMinute: number;
  bufferMinutes: number;
  slotGranularityMinutes: number;
  calendarIdentifier: string | null;
  autoRebalance: boolean;
};

export type CalendarTask = {
  id: string;
  title: string;
  displayTitle: string;
  category: TaskCategory | null;
  startDate: string;
  endDate: string;
  durationMinutes: number;
  isDone: boolean;
};

export type AppState = {
  accessState: CalendarAccessState;
  calendars: CalendarOption[];
  settings: SchedulingSettings;
  tasks: CalendarTask[];
  selectedDate: string;
  isLoading: boolean;
};

export type NativeRequest<TPayload = unknown> = {
  id: string;
  type: string;
  payload?: TPayload;
};

export type NativeResponse<TResult = unknown> = {
  id: string;
  ok: boolean;
  result?: TResult;
  error?: string;
};

export const categories: TaskCategory[] = ["CS", "Bugs", "Feature", "Pair", "Investigation"];
export const durations = [5, 10, 15, 20, 30, 45, 60, 90, 120];
