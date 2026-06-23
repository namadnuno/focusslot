import { ArrowRight, Check, Clock, Edit3, MoreHorizontal, RotateCcw, Trash2 } from "lucide-react";
import { categoryStyles } from "@/lib/categories";
import type { CalendarTask } from "@/lib/types";
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

export function TaskList({
  tasks,
  onEdit,
  onDone,
  onMove,
  onMoveBy,
  onDelete
}: {
  tasks: CalendarTask[];
  onEdit: (task: CalendarTask) => void;
  onDone: (task: CalendarTask) => void;
  onMove: (task: CalendarTask) => void;
  onMoveBy: (task: CalendarTask) => void;
  onDelete: (task: CalendarTask) => void;
}) {
  if (tasks.length === 0) {
    return (
      <Card className="grid h-full place-items-center p-6 text-center">
        <div>
          <Clock className="mx-auto h-8 w-8 text-muted-foreground" />
          <h3 className="mt-3 text-sm font-medium">No tasks</h3>
          <p className="mt-1 text-xs text-muted-foreground">No [Task] events for this day.</p>
        </div>
      </Card>
    );
  }

  return (
    <div className="h-full space-y-2 overflow-y-auto pr-1">
      {tasks.map((task) => (
        <TaskItem
          key={task.id}
          task={task}
          onEdit={onEdit}
          onDone={onDone}
          onMove={onMove}
          onMoveBy={onMoveBy}
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
  onMoveBy,
  onDelete
}: {
  task: CalendarTask;
  onEdit: (task: CalendarTask) => void;
  onDone: (task: CalendarTask) => void;
  onMove: (task: CalendarTask) => void;
  onMoveBy: (task: CalendarTask) => void;
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
            <DropdownMenuItem onSelect={() => onMoveBy(task)}>
              <ArrowRight className="h-4 w-4" />
              Move…
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
