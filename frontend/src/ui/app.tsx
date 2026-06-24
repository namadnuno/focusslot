import { ArrowRight, CalendarClock, Check, Edit3, Plus, Settings } from "lucide-react";
import { useFocusSlot } from "@/lib/use-focus-slot";
import type { TaskFilter } from "@/lib/use-focus-slot";
import { formatDate } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle
} from "@/components/ui/sheet";
import { DayFilterControl } from "./day-filter-control";
import { AccessDenied, Shell } from "./shell";
import { SettingsPanel } from "./settings-panel";
import { EditTaskForm, MoveTaskForm, NewTaskForm } from "./task-forms";
import { TaskList } from "./task-list";

export function App() {
  const focusSlot = useFocusSlot();
  const {
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
    selectDate,
    handleDayFilterChange
  } = focusSlot;

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
          <div className="grid h-10 w-10 place-items-center rounded-2xl bg-gradient-to-br from-blue-500 to-indigo-700 text-white shadow-md shadow-indigo-500/25 ring-1 ring-inset ring-white/15">
            <CalendarClock className="h-5 w-5" />
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
        <SettingsPanel
          state={state}
          disabled={isBusy}
          onChange={updateSettings}
          onApplyReminderToExisting={applyReminderToExisting}
        />
      ) : (
        <>
          <section className="flex min-h-0 flex-1 flex-col">
            <div className="mb-3 flex items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <h2 className="text-sm font-semibold">Tasks</h2>
                {isBusy && <span className="text-xs text-muted-foreground">Syncing...</span>}
              </div>
              <Tabs value={taskFilter} onValueChange={(value) => setTaskFilter(value as TaskFilter)}>
                <TabsList className="h-7">
                  <TabsTrigger value="active" className="text-xs">
                    Active
                  </TabsTrigger>
                  <TabsTrigger value="done" className="text-xs">
                    Done
                  </TabsTrigger>
                </TabsList>
              </Tabs>
            </div>
            <div className="min-h-0 flex-1">
              <TaskList
                tasks={visibleTasks}
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
                onMoveBy={setMovingTask}
                onDelete={(task) =>
                  runMutation(
                    "deleteTask",
                    { eventID: task.id, selectedDate: selectedDateISO },
                    "Deleted task"
                  )
                }
              />
            </div>
          </section>

          <Button className="w-full" onClick={() => setIsNewTaskOpen(true)}>
            <Plus className="h-4 w-4" />
            New task
          </Button>

          <Sheet
            open={isNewTaskOpen || editDraft !== null || movingTask !== null}
            onOpenChange={(open) => {
              if (!open) {
                setIsNewTaskOpen(false);
                setEditDraft(null);
                setMovingTask(null);
              }
            }}
          >
            <SheetContent
              side="bottom"
              className="max-h-[92%] gap-0 overflow-y-auto rounded-t-2xl"
            >
              <SheetHeader>
                <SheetTitle className="flex items-center gap-2.5">
                  <span className="grid h-7 w-7 place-items-center rounded-lg bg-primary/10 text-primary">
                    {movingTask ? (
                      <ArrowRight className="h-4 w-4" />
                    ) : editDraft ? (
                      <Edit3 className="h-4 w-4" />
                    ) : (
                      <Plus className="h-4 w-4" />
                    )}
                  </span>
                  {movingTask ? "Move task" : editDraft ? "Edit task" : "New task"}
                </SheetTitle>
                <SheetDescription className="sr-only">
                  {movingTask
                    ? "Shift a task to a later time."
                    : editDraft
                      ? "Edit an existing task."
                      : "Create a new task."}
                </SheetDescription>
              </SheetHeader>

              {movingTask ? (
                <MoveTaskForm
                  task={movingTask}
                  disabled={isBusy}
                  onMove={(option) => moveTask(movingTask, option)}
                  onCancel={() => setMovingTask(null)}
                />
              ) : editDraft ? (
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
                  customTimeEnabled={customTimeEnabled}
                  customStartDate={customStartDate}
                  disabled={isBusy}
                  onTitleChange={setTitle}
                  onCategoryChange={setCategory}
                  onDurationChange={setDurationMinutes}
                  onCustomTimeToggle={setCustomTimeEnabled}
                  onCustomStartChange={setCustomStartDate}
                  onSubmit={addTask}
                />
              )}
            </SheetContent>
          </Sheet>
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
