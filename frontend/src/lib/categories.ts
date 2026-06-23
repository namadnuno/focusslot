import type { TaskCategory } from "./types";

/** Tailwind classes for a category's tinted badge / active pill. */
export const categoryStyles: Record<TaskCategory, string> = {
  CS: "border-blue-500/20 bg-blue-500/10 text-blue-700 dark:text-blue-300",
  Bugs: "border-red-500/20 bg-red-500/10 text-red-700 dark:text-red-300",
  Feature: "border-violet-500/20 bg-violet-500/10 text-violet-700 dark:text-violet-300",
  Pair: "border-amber-500/20 bg-amber-500/10 text-amber-700 dark:text-amber-300",
  Investigation: "border-teal-500/20 bg-teal-500/10 text-teal-700 dark:text-teal-300"
};
