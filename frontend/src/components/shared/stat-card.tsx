import React from "react";
import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";

interface StatCardProps {
  title: string;
  value: string | number;
  subtitle?: string;
  icon: React.ElementType;
  iconColor?: "primary" | "emerald" | "amber" | "rose" | "purple";
  badge?: string;
  className?: string;
}

export function StatCard({
  title,
  value,
  subtitle,
  icon: Icon,
  iconColor = "primary",
  badge,
  className,
}: StatCardProps) {
  const colorStyles = {
    primary: "bg-primary/10 text-primary-400 border-primary/20",
    emerald: "bg-emerald-500/10 text-accent-emerald border-emerald-500/20",
    amber: "bg-amber-500/10 text-accent-amber border-amber-500/20",
    rose: "bg-rose-500/10 text-accent-rose border-rose-500/20",
    purple: "bg-purple-500/10 text-accent-purple border-purple-500/20",
  };

  return (
    <Card className={cn("p-6 flex flex-col justify-between glass-card-hover", className)}>
      <div className="flex items-center justify-between mb-4">
        <span className="text-xs font-medium text-slate-400">{title}</span>
        <div className={cn("p-2 rounded-xl border", colorStyles[iconColor])}>
          <Icon className="w-4 h-4" />
        </div>
      </div>

      <div>
        <div className="flex items-baseline gap-2">
          <span className="text-2xl font-heading font-extrabold text-white">{value}</span>
          {badge && (
            <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-950 text-accent-emerald border border-emerald-800/40">
              {badge}
            </span>
          )}
        </div>
        {subtitle && <p className="text-xs text-slate-400 mt-1">{subtitle}</p>}
      </div>
    </Card>
  );
}
