import { Check, Clock, Edit3, MoreHorizontal, RotateCcw, Trash2 } from "lucide-react";
import type { CalendarTask, TaskCategory } from "@/lib/types";
import { formatTime } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger
} from "@/components/ui/dropdown-menu";

const categoryStyles: Record<TaskCategory, string> = {
  CS: "border-blue-500/20 bg-blue-500/10 text-blue-700 dark:text-blue-300",
  Bugs: "border-red-500/20 bg-red-500/10 text-red-700 dark:text-red-300",
  Feature: "border-violet-500/20 bg-violet-500/10 text-violet-700 dark:text-violet-300",
  Pair: "border-amber-500/20 bg-amber-500/10 text-amber-700 dark:text-amber-300",
  Investigation: "border-teal-500/20 bg-teal-500/10 text-teal-700 dark:text-teal-300"
};

export function TaskList({
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
