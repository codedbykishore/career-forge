'use client';

import { Zap } from 'lucide-react';

/**
 * "Powered by Amazon Bedrock" badge — shows on all AI-powered pages
 * (resume generator, skill gap, tailored resumes, roadmap generation)
 */
export function BedrockBadge({
  variant = 'inline',
  className = '',
}: {
  variant?: 'inline' | 'footer' | 'compact';
  className?: string;
}) {
  if (variant === 'compact') {
    return (
      <span
        className={`inline-flex items-center gap-1 text-[10px] text-muted-foreground ${className}`}
      >
        <Zap className="h-2.5 w-2.5" aria-hidden="true" />
        Amazon Bedrock
      </span>
    );
  }

  if (variant === 'footer') {
    return (
      <div
        className={`flex items-center justify-center gap-2 py-3 text-xs text-muted-foreground border-t border-border/40 mt-6 ${className}`}
      >
        <div className="flex items-center gap-1.5 rounded-full border border-primary/15 bg-primary/5 px-3 py-1">
          <Zap className="h-3 w-3 text-primary" aria-hidden="true" />
          <span>Powered by Amazon{'\u00A0'}Bedrock</span>
        </div>
      </div>
    );
  }

  // Default: inline badge
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full border border-primary/15 bg-primary/5 px-2.5 py-0.5 text-xs text-primary ${className}`}
    >
      <Zap className="h-3 w-3" aria-hidden="true" />
      Powered by Amazon{'\u00A0'}Bedrock
    </span>
  );
}
