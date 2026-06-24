import { ArrowRight, Check, Clock, Edit3, MoreHorizontal, RotateCcw, Trash2 } from "lucide-react";
import { categoryAccents, categoryStyles, defaultAccent } from "@/lib/categories";
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
  const accent = task.category ? categoryAccents[task.category] : defaultAccent;
  const rail = task.isDone ? "bg-emerald-500" : accent.rail;
  const glow = task.isDone ? "shadow-emerald-500/50" : accent.glow;
  const tint = task.isDone ? "from-emerald-500/10" : accent.tint;

  return (
    <Card
      className={`group relative overflow-hidden rounded-xl border-border/60 p-3 backdrop-blur-sm transition-all duration-300 hover:-translate-y-px hover:border-border hover:shadow-lg hover:shadow-black/5 ${
        task.isDone ? "opacity-70" : ""
      }`}
    >
      {/* ambient category tint sweeping in from the rail */}
      <div
        className={`pointer-events-none absolute inset-0 bg-gradient-to-r ${tint} via-transparent to-transparent opacity-60 transition-opacity duration-300 group-hover:opacity-100`}
      />
      {/* glowing vertical rail */}
      <div className={`absolute inset-y-2.5 left-0 w-[3px] rounded-r-full shadow-[0_0_8px] ${rail} ${glow}`} />
      <div className="relative flex items-center gap-3 pl-2.5">
        <div className="min-w-0 flex-1">
          <div className="flex min-w-0 items-center gap-2">
            {task.category && (
              <Badge className={`${categoryStyles[task.category]} text-[10px] uppercase tracking-wider`}>
                {task.category}
              </Badge>
            )}
            <p className={`truncate text-sm font-medium ${task.isDone ? "text-muted-foreground line-through" : ""}`}>
              {task.displayTitle}
            </p>
          </div>
          <p className="mt-1 flex items-center gap-1.5 text-xs text-muted-foreground">
            <span className={`h-1.5 w-1.5 rounded-full ${task.isDone ? "bg-emerald-500" : accent.dot}`} />
            <span className="tabular-nums">
              {formatTime(start)} – {formatTime(end)}
            </span>
          </p>
        </div>
        <span className="rounded-full border border-border/70 bg-muted/50 px-2 py-0.5 text-[11px] font-medium tabular-nums text-muted-foreground">
          {task.durationMinutes}m
        </span>
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
