import type { TaskCategory } from "./types";

/** Tailwind classes for a category's tinted badge / active pill. */
export const categoryStyles: Record<TaskCategory, string> = {
  CS: "border-blue-500/20 bg-blue-500/10 text-blue-700 dark:text-blue-300",
  Bugs: "border-red-500/20 bg-red-500/10 text-red-700 dark:text-red-300",
  Feature: "border-violet-500/20 bg-violet-500/10 text-violet-700 dark:text-violet-300",
  Pair: "border-amber-500/20 bg-amber-500/10 text-amber-700 dark:text-amber-300",
  Investigation: "border-teal-500/20 bg-teal-500/10 text-teal-700 dark:text-teal-300",
  Life: "border-pink-500/20 bg-pink-500/10 text-pink-700 dark:text-pink-300"
};

/** Accent color per category, used for the glowing rail + ambient tint on a task card. */
export const categoryAccents: Record<TaskCategory, { rail: string; glow: string; tint: string; dot: string }> = {
  CS: { rail: "bg-blue-500", glow: "shadow-blue-500/50", tint: "from-blue-500/10", dot: "bg-blue-500" },
  Bugs: { rail: "bg-red-500", glow: "shadow-red-500/50", tint: "from-red-500/10", dot: "bg-red-500" },
  Feature: { rail: "bg-violet-500", glow: "shadow-violet-500/50", tint: "from-violet-500/10", dot: "bg-violet-500" },
  Pair: { rail: "bg-amber-500", glow: "shadow-amber-500/50", tint: "from-amber-500/10", dot: "bg-amber-500" },
  Investigation: { rail: "bg-teal-500", glow: "shadow-teal-500/50", tint: "from-teal-500/10", dot: "bg-teal-500" },
  Life: { rail: "bg-pink-500", glow: "shadow-pink-500/50", tint: "from-pink-500/10", dot: "bg-pink-500" }
};

/** Fallback accent for uncategorized/legacy tasks. */
export const defaultAccent = {
  rail: "bg-primary",
  glow: "shadow-primary/50",
  tint: "from-primary/10",
  dot: "bg-primary"
} as const;
