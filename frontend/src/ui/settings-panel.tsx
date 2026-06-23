import type { AppState, SchedulingSettings } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { NativeSelect as Select, NativeSelectOption as Option } from "@/components/ui/native-select";
import { Switch } from "@/components/ui/switch";

export function SettingsPanel({
  state,
  disabled,
  onChange,
  onApplyReminderToExisting
}: {
  state: AppState;
  disabled: boolean;
  onChange: (settings: SchedulingSettings) => void;
  onApplyReminderToExisting: () => void;
}) {
  const settings = state.settings;

  function patch(partial: Partial<SchedulingSettings>) {
    onChange({ ...settings, ...partial });
  }

  return (
    <Card className="flex-1 space-y-4 overflow-y-auto p-4">
      <div>
        <h2 className="text-sm font-semibold">Settings</h2>
        <p className="text-xs text-muted-foreground">Stored locally on this Mac.</p>
      </div>

      <Field label="Task calendar">
        <Select
          className="w-full"
          value={settings.calendarIdentifier ?? ""}
          onChange={(event) => patch({ calendarIdentifier: event.target.value || null })}
        >
          <Option value="">Default writable calendar</Option>
          {state.calendars.map((calendar) => (
            <Option key={calendar.id} value={calendar.id}>
              {calendar.title} ({calendar.source})
            </Option>
          ))}
        </Select>
      </Field>

      <div className="grid grid-cols-2 gap-3">
        <TimeField
          label="Workday start"
          hour={settings.workdayStartHour}
          minute={settings.workdayStartMinute}
          onChange={(hour, minute) => patch({ workdayStartHour: hour, workdayStartMinute: minute })}
        />
        <TimeField
          label="Workday end"
          hour={settings.workdayEndHour}
          minute={settings.workdayEndMinute}
          onChange={(hour, minute) => patch({ workdayEndHour: hour, workdayEndMinute: minute })}
        />
        <TimeField
          label="Lunch start"
          hour={settings.lunchStartHour}
          minute={settings.lunchStartMinute}
          onChange={(hour, minute) => patch({ lunchStartHour: hour, lunchStartMinute: minute })}
        />
        <TimeField
          label="Lunch end"
          hour={settings.lunchEndHour}
          minute={settings.lunchEndMinute}
          onChange={(hour, minute) => patch({ lunchEndHour: hour, lunchEndMinute: minute })}
        />
      </div>

      <div className="grid grid-cols-2 gap-3">
        <Field label="Buffer">
          <Input
            type="number"
            min={0}
            max={60}
            step={5}
            value={settings.bufferMinutes}
            onChange={(event) => patch({ bufferMinutes: Number(event.target.value) })}
          />
        </Field>
        <Field label="Granularity">
          <Input
            type="number"
            min={1}
            max={30}
            value={settings.slotGranularityMinutes}
            onChange={(event) => patch({ slotGranularityMinutes: Number(event.target.value) })}
          />
        </Field>
      </div>

      <Field label="Reminder">
        <Select
          className="w-full"
          value={settings.reminderMinutes ?? ""}
          onChange={(event) =>
            patch({ reminderMinutes: event.target.value === "" ? null : Number(event.target.value) })
          }
        >
          <Option value="">No reminder</Option>
          <Option value={0}>At start time</Option>
          <Option value={5}>5 minutes before</Option>
          <Option value={10}>10 minutes before</Option>
          <Option value={30}>30 minutes before</Option>
        </Select>
        <Button
          type="button"
          variant="outline"
          size="sm"
          disabled={disabled}
          onClick={onApplyReminderToExisting}
        >
          Apply to upcoming tasks
        </Button>
        <span className="text-xs font-normal text-muted-foreground">
          New tasks use this automatically. Use the button to update tasks already on your calendar (today onward).
        </span>
      </Field>

      <div className="flex items-center justify-between rounded-lg border p-3 text-sm">
        <Label htmlFor="auto-rebalance">Auto-rebalance tasks</Label>
        <Switch
          id="auto-rebalance"
          checked={settings.autoRebalance}
          onCheckedChange={(checked) => patch({ autoRebalance: checked })}
        />
      </div>
    </Card>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="space-y-1.5 text-sm">
      <span className="text-xs font-medium text-muted-foreground">{label}</span>
      {children}
    </label>
  );
}

function TimeField({
  label,
  hour,
  minute,
  onChange
}: {
  label: string;
  hour: number;
  minute: number;
  onChange: (hour: number, minute: number) => void;
}) {
  const value = `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;

  return (
    <Field label={label}>
      <Input
        type="time"
        step={300}
        value={value}
        onChange={(event) => {
          const [nextHour, nextMinute] = event.target.value.split(":").map(Number);
          onChange(nextHour, nextMinute);
        }}
      />
    </Field>
  );
}
