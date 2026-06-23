import { CalendarPlus, Check, Settings } from "lucide-react";
import { useFocusSlot } from "@/lib/use-focus-slot";
import { formatDate } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { DayFilterControl } from "./day-filter-control";
import { AccessDenied, Shell } from "./shell";
import { SettingsPanel } from "./settings-panel";
import { EditTaskForm, NewTaskForm } from "./task-forms";
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
    editDraft,
    setEditDraft,
    dayFilter,
    isCustomDateOpen,
    setIsCustomDateOpen,
    refresh,
    runMutation,
    addTask,
    saveTask,
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

          <Separator className="my-2" />

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
