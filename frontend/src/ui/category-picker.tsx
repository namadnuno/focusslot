import { categoryStyles } from "@/lib/categories";
import type { TaskCategory } from "@/lib/types";
import { categories } from "@/lib/types";
import { cn } from "@/lib/utils";

export function CategoryPicker({
  value,
  onChange
}: {
  value: TaskCategory;
  onChange: (value: TaskCategory) => void;
}) {
  return (
    <div className="flex flex-wrap gap-1.5">
      {categories.map((category) => {
        const isActive = category === value;
        return (
          <button
            key={category}
            type="button"
            aria-pressed={isActive}
            onClick={() => onChange(category)}
            className={cn(
              "rounded-full border px-2.5 py-1 text-xs font-medium transition-colors",
              isActive
                ? categoryStyles[category]
                : "border-transparent bg-muted text-muted-foreground hover:bg-accent hover:text-foreground"
            )}
          >
            {category}
          </button>
        );
      })}
    </div>
  );
}
