'use client';

import { cn } from '@/lib/utils';

/* ─── Base Skeleton ──────────────────────────────────────────────────────── */

export function Skeleton({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        'animate-pulse rounded-md bg-muted',
        className,
      )}
      {...props}
    />
  );
}

/* ─── Card Skeleton — generic card placeholder ───────────────────────────── */

export function CardSkeleton({ lines = 3 }: { lines?: number }) {
  return (
    <div className="rounded-xl border bg-card p-5 space-y-4">
      <div className="flex items-center gap-3">
        <Skeleton className="h-10 w-10 rounded-full" />
        <div className="space-y-2 flex-1">
          <Skeleton className="h-4 w-1/3" />
          <Skeleton className="h-3 w-1/4" />
        </div>
      </div>
      <div className="space-y-2">
        {Array.from({ length: lines }).map((_, i) => (
          <Skeleton
            key={i}
            className="h-3"
            style={{ width: `${85 - i * 15}%` }}
          />
        ))}
      </div>
    </div>
  );
}

/* ─── Table Row Skeleton — for list/table views ──────────────────────────── */

export function TableRowSkeleton({ cols = 5 }: { cols?: number }) {
  return (
    <div className="flex items-center gap-4 px-4 py-3">
      <Skeleton className="h-8 w-8 rounded-full shrink-0" />
      <div className="flex-1 space-y-2">
        <Skeleton className="h-4 w-1/3" />
        <Skeleton className="h-3 w-1/4" />
      </div>
      {Array.from({ length: cols - 2 }).map((_, i) => (
        <Skeleton key={i} className="h-6 w-16 shrink-0" />
      ))}
    </div>
  );
}

/* ─── Resume List Skeleton ───────────────────────────────────────────────── */

export function ResumeListSkeleton() {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="space-y-2">
          <Skeleton className="h-6 w-32" />
          <Skeleton className="h-4 w-24" />
        </div>
        <Skeleton className="h-9 w-36 rounded-lg" />
      </div>
      <div className="rounded-lg border divide-y overflow-hidden">
        {[1, 2, 3].map((i) => (
          <div key={i} className="flex items-center gap-4 px-4 py-3">
            <Skeleton className="h-8 w-8 rounded-full shrink-0" />
            <div className="flex-1 space-y-2">
              <Skeleton className="h-4 w-1/3" />
              <Skeleton className="h-3 w-1/4" />
            </div>
            <Skeleton className="h-6 w-16" />
            <Skeleton className="h-8 w-24" />
          </div>
        ))}
      </div>
    </div>
  );
}

/* ─── Skill Gap Skeleton ─────────────────────────────────────────────────── */

export function SkillGapSkeleton() {
  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <Skeleton className="h-6 w-48" />
        <Skeleton className="h-4 w-80" />
      </div>
      <div>
        <Skeleton className="h-4 w-36 mb-3" />
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
          {Array.from({ length: 8 }).map((_, i) => (
            <Skeleton key={i} className="h-24 rounded-xl" />
          ))}
        </div>
      </div>
      <Skeleton className="h-10 w-40 rounded-lg" />
    </div>
  );
}

/* ─── Kanban Skeleton ────────────────────────────────────────────────────── */

export function KanbanSkeleton() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="space-y-2">
          <Skeleton className="h-6 w-40" />
          <Skeleton className="h-4 w-64" />
        </div>
        <Skeleton className="h-9 w-36 rounded-lg" />
      </div>
      <div className="grid gap-6 lg:grid-cols-5">
        <div className="lg:col-span-2">
          <Skeleton className="h-64 rounded-xl" />
        </div>
        <div className="lg:col-span-3">
          <div className="rounded-xl border p-4">
            <div className="flex gap-3">
              {[1, 2, 3, 4].map((i) => (
                <div key={i} className="flex-1 space-y-3">
                  <Skeleton className="h-5 w-20" />
                  <Skeleton className="h-32 rounded-lg" />
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ─── Bedrock Operation Loading ──────────────────────────────────────────── */

export function BedrockLoadingSkeleton({
  title = 'Processing with AI...',
  description = 'Amazon Bedrock is analyzing your data. This may take 3–10 seconds.',
}: {
  title?: string;
  description?: string;
}) {
  return (
    <div className="flex flex-col items-center py-12 space-y-4 animate-fade-in-up">
      <div className="relative">
        <div className="h-16 w-16 rounded-full border-4 border-primary/20" />
        <div className="absolute inset-0 h-16 w-16 rounded-full border-4 border-primary border-t-transparent animate-spin" />
      </div>
      <div className="text-center space-y-1">
        <p className="font-medium text-sm">{title}</p>
        <p className="text-xs text-muted-foreground">{description}</p>
      </div>
      <div className="flex items-center gap-1.5 text-[10px] text-muted-foreground">
        <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" />
        </svg>
        Powered by Amazon Bedrock
      </div>
    </div>
  );
}
